/*
    TRIGGER SETTINGS

    VARIABLE NAME: AiPrecisionBomberStrike
    TYPE: None
    ACTIVATION: Anybody
    ACTIVATION TYPE: Not Present
    REPEATABLE: No
	SERVER ONLY: No
	CONDITION: this
	INTERVAL: 0.5
*/

[] spawn {
	private _blufor_bomb = "Bomb_04_Plane_CAS_01_F";
    private _opfor_bomb = "Bomb_03_Plane_CAS_02_F";
    private _indep_bomb = "GBU12BombLauncher_Plane_Fighter_03_F";
	
    private _blufor_bomber = "B_Plane_CAS_01_F";
    private _opfor_bomber = "O_Plane_CAS_02_F";
    private _indep_bomber = "I_Plane_Fighter_03_CAS_F";

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

            systemchat format ["DEBUG - Group leader '%1' (%2) requested PRECISION BOMBER STRIKE at enemy '%3' (%4) position (Grid: %5).", name _observer, side _observer, _targetType, side _target, _targetGrid];
        };

        [_observer, _target] call _fnPrecisionBomberStrike;
    };

    private _fnPrecisionBomberStrike = {
        params ["_observer", "_target"];

		_muzzleClass = "";
        _vehicleClass = "";
        _targetSide = side _target;
		_observerSide = side _observer;
        
		if (side _observer == west) then {_vehicleClass = _blufor_bomber; _muzzleClass = _blufor_bomb};
        if (side _observer == east) then {_vehicleClass = _opfor_bomber; _muzzleClass = _opfor_bomb};
        if (side _observer == resistance) then {_vehicleClass = _indep_bomber; _muzzleClass = _indep_bomb};

        _engageDistance = 1500;
        _spawnHeight = 750;
        _spawnDistance = 3500;
        _angle = random 360;
        _spawnPos = getPosATL _target vectorAdd [sin _angle * _spawnDistance, cos _angle * _spawnDistance, 0];

        _bomber = createVehicle [_vehicleClass, _spawnPos, [], 0, "FLY"];
        _bomber setPosATL [(getPosATL _bomber select 0), (getPosATL _bomber select 1), (getPosATL _bomber select 2) + _spawnHeight];
		_bomber setDir (_bomber getDir _target);
        createVehicleCrew _bomber;
		
		_laserSpot = createVehicle ["LaserTargetW" , getPosATL _target, [], 0, "CAN_COLLIDE"];
        _laserSpot attachTo [_target, [0,0,0]];

        waitUntil {alive driver _bomber};

		_bombDrop = false;
        _showDebug = true;

        while {alive driver _bomber} do {
            _bomber setFuel 1;
            _bomber setSkill 1;
            _bomber setVehicleAmmo 1;

            _bomber setSpeedMode "FULL";
            _bomber setCombatMode "GREEN";
            _bomber setBehaviour "AWARE";

            _bomber flyInHeight _spawnHeight;

            if (_show_debug_messages) then {
                hint format ["Bomber altitude: %1m\nTarget distance: %2m", (getPosATL _bomber select 2) toFixed 2, (_bomber distance _target) toFixed 2];
            };

            if ((alive _target) && ((_target isKindOf "Man" && isNull objectParent _target) || (_target isKindOf "AllVehicles" && {alive _x} count (crew _target) > 0))) then {
                _bomber doMove (getPosATL _target);
                
                if (_bomber distance _target <= _engageDistance) then {
					if !(_bombDrop) then {
						_bomber reveal _target;
						
						[_bomber, _laserSpot, _muzzleClass] spawn {
							params ["_bomber", "_laserSpot", "_muzzleClass"];
							
							for "_i" from 1 to 2 do {
								_bomber fireAtTarget [_laserSpot, _muzzleClass]; 
								sleep 5;
							};
							
							deleteVehicle _laserSpot;
						};
						
						_bombDrop = true;
					};
                } else {
                    _bomber forgetTarget _target;
                };
            } else {
                _bomber doMove (_spawnPos);
                
                if (_bomber distance _spawnPos <= 1000) exitWith {
                    {deleteVehicle _x} forEach crew _bomber;
                    deleteVehicle _bomber;
                };

                if ((_show_debug_messages) && (_showDebug)) then {
                    systemchat format ["DEBUG - The PRECISION BOMBER (%1) neutralized the target (%2)!", _observerSide, _targetSide];
                    _showDebug = false;
                };
            };

            sleep 1;
        };

        if (_show_debug_messages) then {

            if ((alive _target) && ((_target isKindOf "Man" && isNull objectParent _target) || (_target isKindOf "AllVehicles" && {alive _x} count (crew _target) > 0))) then {

                if !(alive _bomber) then {
                    systemchat format ["DEBUG - The PRECISION BOMBERF (%1) was shot down.", _observerSide];
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