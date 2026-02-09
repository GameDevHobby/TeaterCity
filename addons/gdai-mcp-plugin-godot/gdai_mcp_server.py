# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "mcp==1.13.0",
#     "httpx==0.28.1",
# ]
# ///

import os
import asyncio
from mcp.server.lowlevel import Server
from mcp.server.lowlevel.server import LifespanResultT
import mcp.types as mt
import httpx
from mcp.shared.session import RequestResponder
from mcp.server.session import ServerSession

GDAI_MCP_SERVER_PORT = int(os.getenv("GDAI_MCP_SERVER_PORT", "3571"))
GDAI_SERVER_VERSION = "0.3.0"
GDAI_HTTP_SERVER_BASE_URL = f"http://localhost:{GDAI_MCP_SERVER_PORT}"


async def http_get(url: str, body = None):
    async with httpx.AsyncClient() as client:
        response = await client.request(method="GET", url=url, json=body)
        response.raise_for_status()
        return response.json()


async def http_post(url: str, body, timeout=5):
    async with httpx.AsyncClient() as client:
        response = await client.post(url, json=body, timeout=timeout)
        response.raise_for_status()
        return response.json()


class GDAIMCPServer(Server):

    async def _handle_initialized_notification(self, notify: mt.InitializedNotification, session: ServerSession):
        client_info = session.client_params.clientInfo
        await http_post(GDAI_HTTP_SERVER_BASE_URL + "/client_initialized", {
            "protocol_version": session.client_params.protocolVersion,
            "client_name": client_info.name,
            "client_version": client_info.version,
        })

    async def _handle_message(
        self,
        message: RequestResponder[mt.ClientRequest, mt.ServerResult] | mt.ClientNotification | Exception,
        session: ServerSession,
        lifespan_context: LifespanResultT,
        raise_exceptions: bool = False,
    ):
        match message:
            case mt.ClientNotification(root=notify):
                if isinstance(notify, mt.InitializedNotification):
                    await self._handle_initialized_notification(notify, session)

        return await super()._handle_message(message, session, lifespan_context, raise_exceptions)


server = GDAIMCPServer("gdai-mcp-godot", version=GDAI_SERVER_VERSION, instructions="""This server is used to interact with the Godot game engine.""")


@server.list_tools()
async def list_tools() -> list[mt.Tool]:
    json = await http_get(GDAI_HTTP_SERVER_BASE_URL + "/tools")
    if not "mcp_tools" in json:
        raise Exception("Error listing tools. Could not find 'mcp_tools' in response.")
    return [mt.Tool(**tool) for tool in json["mcp_tools"]]


async def send_tool_progress_notification(session: ServerSession, progress_token: str):
    i = 0
    while True:
        await session.send_progress_notification(
            progress_token=progress_token,
            progress=float(i+1),
            message="processing...",
            related_request_id=progress_token
        )
        i += 1
        await asyncio.sleep(2)


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list:
    ctx = server.request_context

    notif_task = asyncio.create_task(send_tool_progress_notification(
        session=ctx.session,
        progress_token=str(ctx.request_id),
    ))

    timeout = 5
    if name == "get_running_scene_screenshot":
        timeout = 30
    if name == "simulate_input":
        timeout = 65

    req_task = asyncio.create_task(http_post(GDAI_HTTP_SERVER_BASE_URL + "/call-tool", {
        "tool_name": name,
        "tool_args": arguments
    }, timeout=timeout))

    try:
        done, pending = await asyncio.wait(
            [notif_task, req_task],
            return_when=asyncio.FIRST_COMPLETED
        )

        for task in pending:
            task.cancel()

        if pending:
            await asyncio.wait(pending)


        for task in done:
            if task == req_task:
                ex = req_task.exception()
                if ex and isinstance(ex, httpx.TimeoutException):
                    raise Exception(f"Timeout calling tool {name}. Took longer than {timeout} seconds.")

                json = req_task.result()

                if json["is_error"]:
                    raise Exception(
                        f"Error calling tool {name}: {json['tool_call_result']}"
                    )

                result_type = json.get("type")
                if result_type == "image":
                    mime_type = json.get("mime_type", "image/jpg")
                    return [mt.ImageContent(type="image", mimeType=mime_type, data=json["tool_call_result"])]
                else:
                    return [mt.TextContent(type="text", text=json["tool_call_result"])]
    except Exception as e:
        notif_task.cancel()
        req_task.cancel()
        await asyncio.wait([notif_task, req_task])
        raise e

@server.list_prompts()
async def list_prompts() -> list[mt.Prompt]:
    json = await http_get(GDAI_HTTP_SERVER_BASE_URL + "/prompts")
    if not "mcp_prompts" in json:
        raise Exception("Error listing prompts. Could not find 'mcp_prompts' in response.")
    return [mt.Prompt(**prompt) for prompt in json["mcp_prompts"]]


@server.get_prompt()
async def get_prompt(name: str, arguments: dict[str, str] | None) -> mt.GetPromptResult:
    if name != "gdai-mcp-default-prompt":
        raise ValueError(f"Unknown prompt: {name}")

    json = await http_get(GDAI_HTTP_SERVER_BASE_URL + f"/prompt", {
        "prompt_name": name,
        "prompt_args": arguments
    })

    if "is_error" in json and json["is_error"]:
        raise ValueError(json["result"])

    messages = json["messages"]

    return mt.GetPromptResult(
        messages=[
            mt.PromptMessage(
                role=message["role"],
                content=mt.TextContent(type="text", text=message["content"]["text"])
            ) for message in messages
        ],
        prompt_name=name
    )


async def run():
    from mcp.server.stdio import stdio_server

    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream, write_stream, server.create_initialization_options()
        )


def main():
    import asyncio
    asyncio.run(run())


if __name__ == "__main__":
    main()