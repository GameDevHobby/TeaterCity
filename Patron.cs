using Godot;
using System;

public partial class Patron : CharacterBody2D
{
    [Export] public float MovementSpeed { get; set; }
    [Export] public NavigationAgent2D NavAgent { get; set; }

    public override void _Ready()
    {
        //NavAgent.Tar
        //NavAgent.TargetReached += OnTargetReached;
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
        else
        {
            Velocity = ToLocal(NavAgent.GetNextPathPosition()).Normalized();
            Velocity = Velocity * MovementSpeed * (float)delta;
        }
        MoveAndSlide();
    }

    public void OnTimerTimeout()
    {
        //var mousePos = GetGlobalMousePosition();
        //NavAgent.SetTargetPosition(mousePos);
    }
}
