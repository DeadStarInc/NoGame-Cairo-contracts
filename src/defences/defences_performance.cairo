%lang starknet

namespace DefencesPerformance {
    namespace Rocket {
        const shield_power = 20;
        const structural_integrity = 2000;
        const weapon_power = 80;
    }

    namespace LightLaser {
        const shield_power = 25;
        const structural_integrity = 2000;
        const weapon_power = 100;
    }

    namespace HeavyLaser {
        const shield_power = 100;
        const structural_integrity = 8000;
        const weapon_power = 250;
    }

    namespace IonCannon {
        const shield_power = 500;
        const structural_integrity = 8000;
        const weapon_power = 150;
    }

    namespace GaussCannon {
        const shield_power = 200;
        const structural_integrity = 35000;
        const weapon_power = 1100;
    }

    namespace PlasmaTurret {
        const shield_power = 300;
        const structural_integrity = 100000;
        const weapon_power = 3000;
    }

    namespace SmallDome {
        const shield_power = 2000;
        const structural_integrity = 20000;
        const weapon_power = 1;
    }

    namespace LargeDome {
        const shield_power = 10000;
        const structural_integrity = 100000;
        const weapon_power = 1;
    }
}
