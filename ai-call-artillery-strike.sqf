/*
    TRIGGER SETTINGS

    VARIABLE NAME: AiCallArtilleryStrike
    TYPE: None
    ACTIVATION: Anybody
    ACTIVATION TYPE: Not Present
    REPEATABLE: No
	SERVER ONLY: No
	CONDITION: this
	INTERVAL: 0.5
*/

[] spawn {
    private _mortar_ammo = "Sh_82mm_AMOS";
    private _howitzer_ammo = "Sh_155mm_AMOS";
    private _rocket_ammo = "R_230mm_HE";
    private _flare_ammo = "F_40mm_White";

    private _allow_marking = true;

    private _cooldown_duration = 120;
    private _min_detection_distance = 200;
    private _max_detection_distance = 1000;
    private _requesting_support_prob = 0.25;
    private _show_debug_messages = true;

    private _player_as_observer = true;
    private _player_as_target = false;

    private _blufor_as_observer = true;
    private _opfor_as_observer = true;
    private _indep_as_observer = true;

    private _man = true;
    private _car = false;
    private _ship = false;
    private _tank = false;
    private _wheeled_apc = false;
    private _tracked_apc = false;
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

        _strikeType = [_target] call _fnStrikeType;

        if (_show_debug_messages) then {
            _targetGrid = mapGridPosition _target;
            _targetType = _target call BIS_fnc_objectType select 1;

            systemchat format ["DEBUG - Group leader '%1' (%2) requested %3 at enemy '%4' (%5) position (Grid: %6).", 
                name _observer, side _observer, _strikeType, _targetType, side _target, _targetGrid
            ];
        };
    };

    private _fnMarkTargetPosition = {
        params ["_target"];

        _posX = getPosATL _target select 0;
		_posY = getPosATL _target select 1;
		_posZ = (getPosATL _target select 2) + 5;

        _smoke = createVehicle ["G_40mm_SmokeRed", [0, 0, 0], [], 0, "NONE"];
        _smoke setPosATL [_posX, _posY, _posZ];
        _smoke setVelocity [0, 0, 1];

        waitUntil {sleep 0.1; (surfaceIsWater getPos _smoke) || (isTouchingGround _smoke )};

        _smoke enableSimulationGlobal false;

        sleep 5;

		deleteVehicle _smoke;
    };

    private _fnMortarStrike = {
        params ["_target"];

        _targetPos = getPosATL _target;
        _ammo = _mortar_ammo;
        _dispersion = 50;
        _rounds = 10;
        _delay = 5;
        _conditionEnd = {false};
        _safeZone = 0;
        _altitude = 1000;
        _speed = 150;
        _sounds = ["shell1", "shell2"];
        
        [_targetPos, _ammo, _dispersion, _rounds, _delay, _conditionEnd, _safeZone, _altitude, _speed, _sounds] spawn BIS_fnc_fireSupportVirtual;
    };

    private _fnHowitzerStrike = {
        params ["_target"];

        _targetPos = getPosATL _target;
        _ammo = _howitzer_ammo;
        _dispersion = 75;
        _rounds = 10;
        _delay = 5;
        _conditionEnd = {false};
        _safeZone = 0;
        _altitude = 1000;
        _speed = 150;
        _sounds = ["shell1", "shell2"];
        
        [_targetPos, _ammo, _dispersion, _rounds, _delay, _conditionEnd, _safeZone, _altitude, _speed, _sounds] spawn BIS_fnc_fireSupportVirtual;
    };

    private _fnRocketStrike = {
        params ["_target"];

        _targetPos = getPosATL _target;
        _ammo = _rocket_ammo;
        _dispersion = 125;
        _rounds = 20;
        _delay = 0.5;
        _conditionEnd = {false};
        _safeZone = 0;
        _altitude = 1000;
        _speed = 100;
        _sounds = ["shell1", "shell2"];
        
        [_targetPos, _ammo, _dispersion, _rounds, _delay, _conditionEnd, _safeZone, _altitude, _speed, _sounds] spawn BIS_fnc_fireSupportVirtual;
    };

    private _fnIlluminationFlares = {
        params ["_target"];

        _targetPos = getPosATL _target;
        _ammo = _flare_ammo;
        _dispersion = 100;
        _rounds = 5;
        _delay = 25;
        _conditionEnd = {false};
        _safeZone = 0;
        _altitude = 250;
        _speed = 10;
        _sounds = [""];

        [_targetPos, _ammo, _dispersion, _rounds, _delay, _conditionEnd, _safeZone, _altitude, _speed, _sounds] spawn BIS_fnc_fireSupportVirtual;
    };

    private _fnStrikeType = {
        params ["_target"];

        _groupSize = count units group _target;
        _isNight = (daytime >= 20 || daytime < 5) && (random 1 <= 0.25);

        if (_allow_marking) then {
            [_target] spawn _fnMarkTargetPosition;
            sleep 10;
        };

        _result = switch (true) do {
            case (_groupSize > 8): {if (_isNight) then {4} else {3}};
            case (_groupSize > 6): {if (_isNight) then {4} else {2}};
            case (_groupSize > 2): {if (_isNight) then {4} else {1}};
            default {0};
        };

        _strikeType = switch (_result) do {
            case 1: {[_target] call _fnMortarStrike; "MORTAR STRIKE"};
            case 2: {[_target] call _fnHowitzerStrike; "HOWITZER STRIKE"};
            case 3: {[_target] call _fnRocketStrike; "ROCKET STRIKE"};
            case 4: {[_target] call _fnIlluminationFlares; "ILLUMINATION FLARES"};
            default {""};
        };

        _strikeType
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