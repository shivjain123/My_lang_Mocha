from "mocha-bio" import *;

function level_num(l: MankoskiLevel) -> int {
    match(l) {
        case MankoskiLevel.NO_PAIN:        return 0;
        case MankoskiLevel.MILD:           return 1;
        case MankoskiLevel.MODERATE:       return 2;
        case MankoskiLevel.SEVERE:         return 3;
        case MankoskiLevel.WORST_POSSIBLE: return 4;
        default:                           return 99;
    };
};

function mankoski_check(didLoad) -> null {
    print(level_num(mankoski_pain(0)));
    print(level_num(mankoski_pain(1)));
    print(level_num(mankoski_pain(3)));
    print(level_num(mankoski_pain(4)));
    print(level_num(mankoski_pain(6)));
    print(level_num(mankoski_pain(7)));
    print(level_num(mankoski_pain(9)));
    print(level_num(mankoski_pain(10)));
};