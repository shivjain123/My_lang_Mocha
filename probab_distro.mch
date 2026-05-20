from "mocha-stats" import *;
function puts(s: str) -> int native puts;

function test_distributions(didLoad) -> null {
    puts("=== 9c. Probability Distributions ===");

    // --- NormalDist ---
    puts("--- NormalDist ---");
    var nd: NormalDist = NormalDist(0.0, 1.0);
    print("Normal(0,1) pdf(0.0): ",    newLine=true);
    print(nd.pdf(0.0),                 newLine=true);  // ~0.3989
    print("Normal(0,1) pdf(1.0): ",    newLine=true);
    print(nd.pdf(1.0),                 newLine=true);  // ~0.2420
    print("Normal(0,1) cdf(0.0): ",    newLine=true);
    print(nd.cdf(0.0),                 newLine=true);  // 0.5
    print("Normal(0,1) cdf(1.96): ",   newLine=true);
    print(nd.cdf(1.96),                newLine=true);  // ~0.9750
    print("Normal(0,1) survival(1.96): ", newLine=true);
    print(nd.survival(1.96),           newLine=true);  // ~0.0250
    print("Normal(0,1) contains(0.5, 0.95): ", newLine=true);
    print(nd.contains(0.5, 0.95),      newLine=true);  // true

    // --- PoissonDist ---
    puts("--- PoissonDist ---");
    var pd: PoissonDist = PoissonDist(3.0);
    print("Poisson(3) pmf(0): ",       newLine=true);
    print(pd.pmf(0),                   newLine=true);  // ~0.0498
    print("Poisson(3) pmf(3): ",       newLine=true);
    print(pd.pmf(3),                   newLine=true);  // ~0.2240
    print("Poisson(3) cdf(3): ",       newLine=true);
    print(pd.cdf(3),                   newLine=true);  // ~0.6472
    print("Poisson(3) survival(5): ",  newLine=true);
    print(pd.survival(5),              newLine=true);  // ~0.0839
    print("Poisson(3) mean: ",         newLine=true);
    print(pd.mean(),                   newLine=true);  // 3.0
    print("Poisson(3) variance: ",     newLine=true);
    print(pd.variance(),               newLine=true);  // 3.0

    // --- BinomialDist ---
    puts("--- BinomialDist ---");
    var bd: BinomialDist = BinomialDist(10, 0.5);
    print("Binomial(10,0.5) pmf(5): ", newLine=true);
    print(bd.pmf(5),                   newLine=true);  // ~0.2461
    print("Binomial(10,0.5) pmf(0): ", newLine=true);
    print(bd.pmf(0),                   newLine=true);  // ~0.0010
    print("Binomial(10,0.5) cdf(5): ", newLine=true);
    print(bd.cdf(5),                   newLine=true);  // ~0.6230
    print("Binomial(10,0.5) survival(7): ", newLine=true);
    print(bd.survival(7),              newLine=true);  // ~0.0547
    print("Binomial(10,0.5) mean: ",   newLine=true);
    print(bd.mean(),                   newLine=true);  // 5.0
    print("Binomial(10,0.5) variance: ", newLine=true);
    print(bd.variance(),               newLine=true);  // 2.5

    // --- ExponentialDist ---
    puts("--- ExponentialDist ---");
    var ed: ExponentialDist = ExponentialDist(2.0);
    print("Exponential(2) pdf(0.5): ", newLine=true);
    print(ed.pdf(0.5),                 newLine=true);  // ~0.7358
    print("Exponential(2) pdf(0.0): ", newLine=true);
    print(ed.pdf(0.0),                 newLine=true);  // 2.0
    print("Exponential(2) cdf(1.0): ", newLine=true);
    print(ed.cdf(1.0),                 newLine=true);  // ~0.8647
    print("Exponential(2) survival(1.0): ", newLine=true);
    print(ed.survival(1.0),            newLine=true);  // ~0.1353
    print("Exponential(2) mean: ",     newLine=true);
    print(ed.mean(),                   newLine=true);  // 0.5
    print("Exponential(2) median: ",   newLine=true);
    print(ed.median(),                 newLine=true);  // ~0.3466
    print("Exponential(2) memoryless(0.5, 1.0): ", newLine=true);
    print(ed.memoryless(0.5, 1.0),     newLine=true);  // ~0.3679

    // --- GammaDist ---
    puts("--- GammaDist ---");
    var gd: GammaDist = GammaDist(2.0, 1.0);
    print("Gamma(2,1) pdf(1.0): ",     newLine=true);
    print(gd.pdf(1.0),                 newLine=true);  // ~0.3679
    print("Gamma(2,1) pdf(2.0): ",     newLine=true);
    print(gd.pdf(2.0),                 newLine=true);  // ~0.2707
    print("Gamma(2,1) mean: ",         newLine=true);
    print(gd.mean(),                   newLine=true);  // 2.0
    print("Gamma(2,1) variance: ",     newLine=true);
    print(gd.variance(),               newLine=true);  // 2.0
    print("Gamma(2,1) mode: ",         newLine=true);
    print(gd.mode(),                   newLine=true);  // 1.0
    var gd2: GammaDist = GammaDist(1.0, 2.0);
    print("Gamma(1,2) is_exponential: ", newLine=true); 
    print(gd2.is_exponential(), newLine=true);         // true
    print("Gamma(2,0.5) is_chi_squared(): ", newLine=true);
    var gd3: GammaDist = GammaDist(2.0, 0.5);
    print(gd3.is_chi_squared(4), newLine=true);

    // --- BetaDist ---
    puts("--- BetaDist ---");
    var beta: BetaDist = BetaDist(2.0, 5.0);
    print("Beta(2,5) mean: ",          newLine=true);
    print(beta.mean(),                 newLine=true);  // ~0.2857
    print("Beta(2,5) pdf(0.3): ",      newLine=true);
    print(beta.pdf(0.3),               newLine=true);  // ~1.8522
    print("Beta(2,5) pdf(0.0): ",      newLine=true);
    print(beta.pdf(0.0),               newLine=true);  // 0.0
    print("Beta(2,5) mean: ",          newLine=true);
    print(beta.mean(),                 newLine=true);  // ~0.2857
    print("Beta(2,5) variance: ",      newLine=true);
    print(beta.variance(),             newLine=true);  // ~0.0255
    print("Beta(2,5) mode: ",          newLine=true);
    print(beta.mode(),                 newLine=true);  // 0.2
    print("Beta(2,5) skewness: ",      newLine=true);
    print(beta.skewness(),             newLine=true);  // ~0.5963

    print("Beta(1,1) is_uniform: ",    newLine=true);
    var beta_uni: BetaDist = BetaDist(1.0, 1.0);
    print(beta_uni.is_uniform(), newLine=true);

    print("Beta(3,3) is_symmetric: ",  newLine=true);
    var beta_sym: BetaDist = BetaDist(3.0, 3.0);
    print(beta_sym.is_symmetric(), newLine=true);
    
    var beta_start: BetaDist = BetaDist(1.0, 1.0);
    var updated: BetaDist = beta_start.update(5, 2);

    // --- GaussianMixture ---
    puts("--- GaussianMixture ---");
    var means: float[]   = [0.0, 5.0];
    var stds: float[]    = [1.0, 1.0];
    var weights: float[] = [0.5, 0.5];
    var gmm: GaussianMixture = GaussianMixture(means, stds, weights);
    print("GMM pdf(0.0): ",            newLine=true);
    print(gmm.pdf(0.0),                newLine=true);  // ~0.1995
    print("GMM pdf(2.5): ",            newLine=true);
    print(gmm.pdf(2.5),                newLine=true);  // ~0.0878
    print("GMM pdf(5.0): ",            newLine=true);
    print(gmm.pdf(5.0),                newLine=true);  // ~0.1995
    print("GMM cdf(0.0): ",            newLine=true);
    print(gmm.cdf(0.0),                newLine=true);  // ~0.2500
    print("GMM mean: ",                newLine=true);
    print(gmm.mean(),                  newLine=true);  // 2.5
    print("GMM variance: ",            newLine=true);
    print(gmm.variance(),              newLine=true);  // ~7.25
    print("GMM dominant_component: ",  newLine=true);
    print(gmm.dominant_component(),    newLine=true);  // 0 (equal weights, first wins)
    print("GMM responsibility(0.0, 0): ", newLine=true);
    print(gmm.responsibility(0.0, 0),  newLine=true);  // ~1.0
    print("GMM responsibility(2.5, 0): ", newLine=true);
    print(gmm.responsibility(2.5, 0),  newLine=true);  // ~0.5
};