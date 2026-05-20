public class string_bench {
    public static void main(String[] args) {

        // Benchmark 1: String concatenation loop
        // Note: using StringBuilder for fairness — raw + concat in Java is extremely slow
        // (each + creates new object, effectively O(n²))
        // If you want raw + concat, replace with the commented version
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 10000; i++) {
            sb.append("a");
        }
        System.out.println(sb.length());

        /* Raw concat version (much slower):
        String result = "";
        for (int i = 0; i < 10000; i++) {
            result += "a";
        }
        System.out.println(result.length());
        */

        // Benchmark 2: String contains
        String haystack = "the quick brown fox jumps over the lazy dog";
        int found = 0;
        for (int j = 0; j < 10000; j++) {
            if (haystack.contains("fox")) {
                found++;
            }
        }
        System.out.println(found);

        // Benchmark 3: String reverse
        String s = "Hello Mocha World";
        String reversed = "";
        for (int k = 0; k < 10000; k++) {
            reversed = new StringBuilder(s).reverse().toString();
        }
        System.out.println(reversed);

        // Benchmark 4: Split
        String csv = "one,two,three,four,five";
        int count = 0;
        for (int l = 0; l < 10000; l++) {
            String[] parts = csv.split(",");
            count += parts.length;
        }
        System.out.println(count);
    }
}
