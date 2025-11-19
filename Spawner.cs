using Godot;
using System;

public partial class Spawner : Marker2D
{

    //have a timer that spawns patrons periodically
    [Export] public PackedScene PatronScene { get; set; }


    public void OnSpawnTimerTimeout()
    {
        var patronInstance = PatronScene.Instantiate<Patron>();
        GetParent().AddChild(patronInstance);
        patronInstance.GlobalPosition = this.GlobalPosition;
    }
}
