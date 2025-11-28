/*
    TRIGGER SETTINGS

    VARIABLE NAME: AiCasAirplaneStrike
    TYPE: None
    ACTIVATION: Anybody
    ACTIVATION TYPE: Not Present
    REPEATABLE: No
	SERVER ONLY: No
	CONDITION: this
	INTERVAL: 0.5
*/

[] spawn {
    private _blufor_airplane = "B_Plane_CAS_01_F";
    private _opfor_airplane = "O_Plane_CAS_02_F";
    private _indep_airplane = "I_Plane_Fighter_03_CAS_F";

    private _cooldown_duration = 120;
    private _min_detection_distance = 100;
    private _max_detection_distance = 1000;
    private _requesting_support_prob = 0.25;
    private _show_debug_messages = true;

    private _player_as_observer = true;
    private _player_as_target = false;

    private _blufor_as_observer = true;
    private _opfor_as_observer = true;
    private _indep_as_observer = true;

    private _man = true;
    private _car = true;
    private _ship = true;
    private _tank = true;
    private _wheeled_apc = true;
    private _tracked_apc = true;
    private _static_weapon = true;

    private _cooldowns = createHashMap;
    _cooldowns set [west, 0];
    _cooldowns set [east, 0];
    _cooldowns set [resistance, 0];

    private _fnTargetDetection = {
        params ["_observer", "_target", "_cooldowns"];

        _distance = _observer distance _target;
        _knowledge = (leader _observer) knowsAbout _target;
        _canSee = [_observer, "VIEW", _target] checkVisibility [eyePos _observer, aimPos _target];

        if ((_distance >= _min_detection_distance && _distance <= _max_detection_distance) && (_knowledge >= 1) && (_canSee >= 1)) then {
            _currentTime = time;
            _observerSide = side _observer;
            _lastCallTime = _cooldowns get _observerSide;

            if (isNil {_lastCallTime}) then {_lastCallTime = 0};
            if (_currentTime < _lastCallTime) exitWith {};

            _isEnemy = [side _observer, side _target] call BIS_fnc_sideIsEnemy;
            
            if (random 1 <= _requesting_support_prob && _isEnemy) then {
                _cooldowns set [_observerSide, _currentTime + _cooldown_duration];
                [_observer, _target] call _fnTargetIdentification;
            };
        };
    };

    private _fnTargetIdentification = {
        params ["_observer", "_target"];

        _valid = switch (true) do {
            case (_target isKindOf "Man"):          {_man};
            case (_target isKindOf "Car"):          {_car};
            case (_target isKindOf "Ship"):         {_ship};
            case (_target isKindOf "Tank"):         {_tank};
            case (_target isKindOf "WheeledAPC"):   {_wheeled_apc};
            case (_target isKindOf "TrackedAPC"):   {_tracked_apc};
            case (_target isKindOf "StaticWeapon"): {_static_weapon};
            default {false};
        };

        if !(_valid) exitWith {};

        if (_show_debug_messages) then {
            _targetGrid = mapGridPosition _target;
            _targetType = _target call BIS_fnc_objectType select 1;

            systemchat format ["DEBUG - Group leader '%1' (%2) requested CAS AIRPLANE STRIKE at enemy '%3' (%4) position (Grid: %5).", name _observer, side _observer, _targetType, side _target, _targetGrid];
        };

        [_observer, _target] call _fnCASAirplaneStrike;
    };

    private _fnCASAirplaneStrike = {
        params ["_observer", "_target"];

        _vehicleClass = "";
        _targetSide = side _target;
		_observerSide = side _observer;
        
		if (side _observer == west) then {_vehicleClass = _blufor_airplane};
        if (side _observer == east) then {_vehicleClass = _opfor_airplane};
        if (side _observer == resistance) then {_vehicleClass = _indep_airplane};

        _engageDistance = 1500;
        _spawnHeight = 350;
        _spawnDistance = 3500;
        _angle = random 360;
        _spawnPos = getPosATL _target vectorAdd [sin _angle * _spawnDistance, cos _angle * _spawnDistance, 0];

        _airplane = createVehicle [_vehicleClass, _spawnPos, [], 0, "FLY"];
        _airplane setPosATL [(getPosATL _airplane select 0), (getPosATL _airplane select 1), (getPosATL _airplane select 2) + _spawnHeight];
        _airplane setDir (_airplane getDir _target);
        createVehicleCrew _airplane;

        waitUntil {alive driver _airplane};

        _showDebug = true;

        while {alive driver _airplane} do {
            _airplane setFuel 1;
            _airplane setSkill 1;
            _airplane setVehicleAmmo 1;

            _airplane setSpeedMode "FULL";
            _airplane setCombatMode "RED";
            _airplane setBehaviour "COMBAT";

            _airplane flyInHeight _spawnHeight;

            if (_show_debug_messages) then {
                hint format ["Airplane altitude: %1m\nTarget distance: %2m", (getPosATL _airplane select 2) toFixed 2, (_airplane distance _target) toFixed 2];
            };

            if ((alive _target) && ((_target isKindOf "Man" && isNull objectParent _target) || (_target isKindOf "AllVehicles" && {alive _x} count (crew _target) > 0))) then {
                _airplane doMove (getPosATL _target);
                
                if (_airplane distance _target <= _engageDistance) then {
                    _airplane reveal _target;
                    _airplane doTarget _target;
                    _airplane doFire _target;
                } else {
                    _airplane forgetTarget _target;
                };
            } else {
                _airplane doMove (_spawnPos);
                
                if (_airplane distance _spawnPos <= 1000) exitWith {
                    {deleteVehicle _x} forEach crew _airplane;
                    deleteVehicle _airplane;
                };

                if ((_show_debug_messages) && (_showDebug)) then {
                    systemchat format ["DEBUG - The CAS AIRPLANE (%1) neutralized the target (%2)!", _observerSide, _targetSide];
                    _showDebug = false;
                };
            };

            sleep 1;
        };

        if (_show_debug_messages) then {

            if ((alive _target) && ((_target isKindOf "Man" && isNull objectParent _target) || (_target isKindOf "AllVehicles" && {alive _x} count (crew _target) > 0))) then {

                if !(alive _airplane) then {
                    systemchat format ["DEBUG - The CAS AIRPLANE (%1) was shot down.", _observerSide];
                };
            };
        };
    };

    while {true} do {
        _targets = (allUnits + vehicles) select {
            (alive _x) && {side _x in [west, east, resistance]}
        };

        _observers = allUnits select {
            (alive _x) && (isNull objectParent _x) && ((side _x == west && _blufor_as_observer) || (side _x == east && _opfor_as_observer) || (side _x == resistance && _indep_as_observer))
        };
        
        {
            _observer = _x;

            {
                _target = _x;

                if (side _observer != side _target) then {

                    if ((_observer == player && _player_as_observer) || (_target == player && _player_as_target) || (_observer != player && _target != player)) then {
                        [_observer, _target, _cooldowns] call _fnTargetDetection;
                    };
                };
            } forEach _targets;
        } forEach _observers;

        sleep 1;
    };
};