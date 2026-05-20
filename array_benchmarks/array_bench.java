// array_bench.java
// Identical operations to Mocha array benchmark

public class array_bench {
    public static void main(String[] args) {

        // =====================================================
        // BENCHMARK 1: Integer array sum (100,000 elements)
        // =====================================================
        int size = 100000;
        int[] arr = new int[size];
        for (int idx = 0; idx < size; idx++) {
            arr[idx] = idx + 1;
        }

        long sum = 0;
        for (int i = 0; i < size; i++) {
            sum += arr[i];
        }
        System.out.println(sum);

        // =====================================================
        // BENCHMARK 2: Array reverse (100,000 elements)
        // =====================================================
        int[] arr2 = new int[size];
        for (int a = 0; a < size; a++) {
            arr2[a] = a;
        }

        int left = 0;
        int right = size - 1;
        while (left < right) {
            int tmp = arr2[left];
            arr2[left] = arr2[right];
            arr2[right] = tmp;
            left++;
            right--;
        }
        System.out.println(arr2[0]);

        // =====================================================
        // BENCHMARK 3: Bubble sort (10,000 elements)
        // =====================================================
        int ssize = 10000;
        int[] sarr = new int[ssize];
        for (int b = 0; b < ssize; b++) {
            sarr[b] = ssize - b;
        }

        for (int outer = 0; outer < ssize - 1; outer++) {
            for (int inner = 0; inner < ssize - outer - 1; inner++) {
                if (sarr[inner] > sarr[inner + 1]) {
                    int t = sarr[inner];
                    sarr[inner] = sarr[inner + 1];
                    sarr[inner + 1] = t;
                }
            }
        }
        System.out.println(sarr[0]);

        // =====================================================
        // BENCHMARK 4: Linear search (10,000 searches)
        // =====================================================
        int found = 0;
        for (int s = 0; s < 10000; s++) {
            int target = s;
            int pos = -1;
            for (int p = 0; p < size; p++) {
                if (arr[p] == target) {
                    pos = p;
                    break;
                }
            }
            if (pos != -1) found++;
        }
        System.out.println(found);

        // =====================================================
        // BENCHMARK 5: Matrix multiply (100x100)
        // =====================================================
        int dim = 100;
        int[][] matA = new int[dim][dim];
        int[][] matB = new int[dim][dim];
        int[][] matC = new int[dim][dim];

        for (int r = 0; r < dim; r++) {
            for (int c = 0; c < dim; c++) {
                matA[r][c] = r + c;
                matB[r][c] = r - c;
                matC[r][c] = 0;
            }
        }

        for (int row = 0; row < dim; row++) {
            for (int col = 0; col < dim; col++) {
                for (int k = 0; k < dim; k++) {
                    matC[row][col] += matA[row][k] * matB[k][col];
                }
            }
        }
        System.out.println(matC[0][0]);
    }
}
