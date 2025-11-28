/*
    TRIGGER SETTINGS

    VARIABLE NAME: AiKamikazeDroneStrike
    TYPE: None
    ACTIVATION: Anybody
    ACTIVATION TYPE: Not Present
    REPEATABLE: No
	SERVER ONLY: No
	CONDITION: this
	INTERVAL: 0.5
*/

[] spawn {
    private _drone_explosive_AP = "R_TBG32V_F";
	private _drone_explosive_AT = "R_PG32V_F";

    private _blufor_drone = "B_UAV_01_F";
    private _opfor_drone = "O_UAV_01_F";
    private _indep_drone = "I_UAV_01_F";

    private _cooldown_duration = 120;
    private _min_detection_distance = 50;
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

            systemchat format ["DEBUG - Group leader '%1' (%2) requested KAMIKAZE DRONE STRIKE at enemy '%3' (%4) position (Grid: %5).", name _observer, side _observer, _targetType, side _target, _targetGrid];
        };

        [_observer, _target] call _fnKamikazeDroneStrike;
    };

	private _fnDroneVelocity = {
		params ["_target", "_drone", "_speed"];

		_vectorDir = (getPosASL _drone) vectorFromTo (getPosASL _target);
		_vectorLat = vectorNormalized (_vectorDir vectorCrossProduct [0, 0, 1]);
		_vectorUp = _vectorLat vectorCrossProduct _vectorDir;
		_velocity = _vectorDir vectorMultiply _speed;
		_drone setVectorDirAndUp [_vectorDir, _vectorUp];
		_drone setVelocity _velocity;
	};
	
	private _fnExplosiveDirection = {
		params ["_target", "_explosive"];

		_vectorDir = (getPosASL _explosive) vectorFromTo (getPosASL _target);
		_vectorDir = vectorNormalized _vectorDir;
		_vectorLat = _vectorDir vectorCrossProduct [0,0,1];
		
		if (_vectorLat isEqualTo [0,0,0]) then {
			_vectorLat = _vectorDir vectorCrossProduct [1,0,0];
		};
		
		_vectorLat = vectorNormalized _vectorLat;
		_vectorUp = _vectorLat vectorCrossProduct _vectorDir;
		_explosive setVectorDirAndUp [_vectorDir, _vectorUp];
	};

	private _fnKamikazeDroneStrike = {
		params ["_observer", "_target"];

		_vehicleClass = "";
        _targetSide = side _target;
		_observerSide = side _observer;

		if (side _observer == west) then {_vehicleClass = _blufor_drone};
        if (side _observer == east) then {_vehicleClass = _opfor_drone};
        if (side _observer == resistance) then {_vehicleClass = _indep_drone};

        _detonation = false;
		_moveSpeed = 100;
		_engageSpeed = 75;
		_engageDistance = 250;
        _spawnHeight = 500;
		_spawnDistance = 1500;
		_angle = random 360;
		_spawnPos = getPosASL _target vectorAdd [sin _angle * _spawnDistance, cos _angle * _spawnDistance, 0];

		_drone = createVehicle [_vehicleClass, _spawnPos, [], 0, "FLY"];
		_drone setPosASL [(getPosASL _drone select 0), (getPosASL _drone select 1), (getPosASL _target select 2) + _spawnHeight];
        _drone setDir (_drone getDir _target);
		createVehicleCrew _drone;

        if (_show_debug_messages) then {
            _observer connectTerminalToUAV _drone;
            [_drone, _target, _observer, 0] call BIS_fnc_liveFeed;

            _dummy = "Sign_Arrow_Direction_Pink_F" createVehicleLocal getPosASL _drone;  
			_dummy attachTo [_drone, [0, 0, 4]];
			[_dummy, [0, -90, 0]] call BIS_fnc_setObjectRotation; 
			_dummy setObjectScale 10; 

            [_drone, _dummy] spawn {
                params ["_drone", "_dummy"];

                waitUntil {sleep 0.025; !(alive _drone)};
                call BIS_fnc_liveFeedTerminate;
                deleteVehicle _dummy;
            };
        };

		waitUntil {alive driver _drone};
		
		while {alive driver _drone} do {
            _drone setFuel 1;
            _drone setSkill 1;
            
            _drone setSpeedMode "FULL";
            _drone setCombatMode "BLUE";
            _drone setBehaviour "CARELESS";

            _drone flyInHeight _spawnHeight;

            if (_show_debug_messages) then {
                hint format ["Drone altitude: %1m\nTarget distance: %2m", (getPosASL _drone select 2) toFixed 2, (_drone distance _target) toFixed 2];
            };

            if ((alive _target) && ((_target isKindOf "Man" && isNull objectParent _target) || (_target isKindOf "AllVehicles" && {alive _x} count (crew _target) > 0))) then {
                _drone doMove (getPosASL _target);
                
                if (_drone distance _target <= _engageDistance) then {
                    _drone reveal _target;
                    _drone lockCameraTo [_target, [0, 0]];
					_canSee = [_drone, "VIEW", _target] checkVisibility [eyePos _drone, aimPos _target];

                    if (_canSee >= 1) then {[_target, _drone, _engageSpeed] call _fnDroneVelocity};
                    if (_drone distance _target <= 25) then {_drone flyInHeight 2;};

                    if (_target isKindOf "Man") then {

                        if (_drone distance _target <= 5) then {
							
							if (!_detonation) then {
							
								for "_i" from 1 to 1 do {
									_explosive = _drone_explosive_AP createVehicle (getPosASL _drone);
									_explosive attachTo [_drone, [0, -3, 1]];
									detach _explosive;
									[_target, _explosive] call _fnExplosiveDirection;
									_explosive setDamage 1;
								};

                                _detonation = true;
							};
                        };
                    } else {

                        if (_drone distance _target <= 15) then {
						
							if (!_detonation) then {
							
								for "_i" from 1 to 3 do {
									_explosive = _drone_explosive_AT createVehicle (getPosASL _drone);
									_explosive attachTo [_drone, [0, -3, 1]];
									detach _explosive;
									[_target, _explosive] call _fnExplosiveDirection;
									_explosive setDamage 1;
								};

                                _detonation = true;
							};
                        };
                    };
                } else {
                    [_target, _drone, _moveSpeed] call _fnDroneVelocity;
                };
            } else {
                _drone doMove (_spawnPos);

                if (_drone distance _spawnPos <= 500) exitWith {
					{deleteVehicle _x} forEach crew _drone;
					deleteVehicle _drone;
				};
            };

			sleep 0.025;
		};

        if (_show_debug_messages) then {
            
            if ((alive _target) && ((_target isKindOf "Man" && isNull objectParent _target) || (_target isKindOf "AllVehicles" && {alive _x} count (crew _target) > 0))) then {

                if !(alive _drone) then {
                    systemchat format ["DEBUG - The KAMIKAZE DRONE (%1) was shot down.", _observerSide];
                };
            } else {
                systemchat format ["DEBUG - The KAMIKAZE DRONE (%1) neutralized the target (%2)!", _observerSide, _targetSide];
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