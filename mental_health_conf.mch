from "mocha-forge" import *;

function main(didLoad) -> null {
    var f: File = open("digital_habits_vs_mental_health.csv", "read");
    var line: str = f.readLine();

    var screen:   float[][] = [[]];
    var tiktok:   float[][] = [[]];
    var sleep:    float[][] = [[]];
    var stress:   float[][] = [[]];
    var social:   float[][] = [[]];
    var mood:     float[] = [];

    line = f.readLine();
    while (line != "") {
        var parts: str[] = line.split(",");
        var r_screen: float[] = [parts[0].toFloat()];
        var r_social: float[] = [parts[1].toFloat()];
        var r_tiktok: float[] = [parts[2].toFloat()];
        var r_sleep:  float[] = [parts[3].toFloat()];
        var r_stress: float[] = [parts[4].toFloat()];
        screen.push(r_screen);
        social.push(r_social);
        tiktok.push(r_tiktok);
        sleep.push(r_sleep);
        stress.push(r_stress);
        mood.push(parts[5].toFloat());
        line = f.readLine();
    };
    f.close();

    var mood_n: float[] = mood.normalize();

    var screen_n: float[][] = screen.normalize_col(0);
    var tiktok_n: float[][] = tiktok.normalize_col(0);
    var sleep_n:  float[][] = sleep.normalize_col(0);
    var stress_n: float[][] = stress.normalize_col(0);
    var social_n: float[][] = social.normalize_col(0);

    // M1: stress alone
    var m1: LinearRegression = LinearRegression(0.01, 200);
    m1.fit(stress_n, mood_n);
    var m1_r2: float = m1.r2(stress_n, mood_n);

    // M2: sleep alone
    var m2: LinearRegression = LinearRegression(0.01, 200);
    m2.fit(sleep_n, mood_n);
    var m2_r2: float = m2.r2(sleep_n, mood_n);

    // M3: stress + sleep
    var stress_sleep: float[][] = [[]];
    var i: int = 0;
    while (i < stress_n.length) {
        var row: float[] = [];
        row.push(stress_n[i][0]);
        row.push(sleep_n[i][0]);
        stress_sleep.push(row);
        i++;
    };
    var m3: LinearRegression = LinearRegression(0.01, 200);
    m3.fit(stress_sleep, mood_n);
    var m3_r2: float = m3.r2(stress_sleep, mood_n);

    // M4: full model
    var full: float[][] = [[]];
    i = 0;
    while (i < stress_n.length) {
        var row: float[] = [];
        row.push(screen_n[i][0]);
        row.push(tiktok_n[i][0]);
        row.push(sleep_n[i][0]);
        row.push(stress_n[i][0]);
        row.push(social_n[i][0]);
        full.push(row);
        i++;
    };
    var m4: LinearRegression = LinearRegression(0.01, 200);
    m4.fit(full, mood_n);
    var m4_r2: float = m4.r2(full, mood_n);

    print("============================================================", newLine=true);
    print("THE CONFOUNDING STORY: stress coefficient across models", newLine=true);
    print("============================================================", newLine=true);
    print("Model                                    stress coef      R²", newLine=true);
    print("------------------------------------------------------------", newLine=true);
    print("M1: stress alone                         $0|4f            $1|4f".format(m1.weights[0], m1_r2), newLine=true);
    print("M2: sleep alone                          —                $0|4f".format(m2_r2), newLine=true);
    print("M3: stress + sleep                       $0|4f            $1|4f".format(m3.weights[0], m3_r2), newLine=true);
    print("M4: full model (stress idx=3)            $0|4f            $1|4f".format(m4.weights[3], m4_r2), newLine=true);
    print("============================================================", newLine=true);

    var pred_norm: float = m1.bias + m1.weights[0] * stress.normalize_val(0, 5.0);
    var pred_mood: float = mood_min + pred_norm * (mood_max - mood_min);
    print("Predicted mood at stress=5: $0|2f".format(pred_mood), newLine=true);
};