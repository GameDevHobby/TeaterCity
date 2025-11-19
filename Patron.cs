using Godot;
using System;

public partial class Patron : CharacterBody2D
{
    [Export] public float MovementSpeed { get; set; }
    [Export] public NavigationAgent2D NavAgent { get; set; }

    private bool started = false;
    public override void _Ready()
    {
        var mousePos = GetGlobalMousePosition();
        NavAgent.SetTargetPosition(mousePos);
    }
    public override void _Process(double delta)
    {
        if (Input.IsActionJustPressed("mouse"))
        {
            var mousePos = GetGlobalMousePosition();
            NavAgent.SetTargetPosition(mousePos);
        }
        //If mouse down, set target position to mouse position
        //    if (Input.IsMouseButtonPressed(MouseButton.Left))
        //    {
        //    }

    }

    public override void _PhysicsProcess(double delta)
    {

        if (NavAgent.IsNavigationFinished())
        {
            Velocity = Vector2.Zero;
        }
        else if (Velocity == Vector2.Zero && started)
        {
            // try and skip the next path position
            var path = NavAgent.GetCurrentNavigationPath();
            var index = NavAgent.GetCurrentNavigationPathIndex();
            if (index + 1 < path.Length)
            {
                var pos = path[index + 1];
                var nextPos = NavAgent.GetNextPathPosition();

                Velocity = ToLocal(pos).Normalized();
                Velocity = Velocity * MovementSpeed * (float)delta;
                started = true;
            }
        }
        else
        {
            Velocity = ToLocal(NavAgent.GetNextPathPosition()).Normalized();
            Velocity = Velocity * MovementSpeed * (float)delta;
            started = true;
        }
        MoveAndSlide();
    }

    public void OnTimerTimeout()
    {
        //var mousePos = GetGlobalMousePosition();
        //NavAgent.SetTargetPosition(mousePos);
    }
}
