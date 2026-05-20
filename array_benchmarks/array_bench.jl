function run_benchmarks()
    # =====================================================
    # BENCHMARK 1: Integer array sum
    # =====================================================
    size_n = 100000
    arr = collect(1:size_n)
    
    total = Int64(0)
    @inbounds for i in 1:size_n
        total += arr[i]
    end
    println(total)
    
    # =====================================================
    # BENCHMARK 2: Array reverse
    # =====================================================
    arr2 = collect(0:size_n-1)
    
    left = 1
    right = size_n
    @inbounds while left < right
        arr2[left], arr2[right] = arr2[right], arr2[left]
        left += 1
        right -= 1
    end
    println(arr2[1])
    
    # =====================================================
    # BENCHMARK 3: Bubble sort
    # =====================================================
    ssize = 10000
    sarr = collect(ssize:-1:1)
    
    @inbounds for outer in 1:ssize-1
        for inner in 1:ssize-outer
            if sarr[inner] > sarr[inner+1]
                sarr[inner], sarr[inner+1] = sarr[inner+1], sarr[inner]
            end
        end
    end
    println(sarr[1])
    
    # =====================================================
    # BENCHMARK 4: Linear search
    # =====================================================
    found = 0
    @inbounds for s in 0:9999
        target = s
        pos = -1
        for p in 1:size_n
            if arr[p] == target
                pos = p
                break
            end
        end
        if pos != -1
            found += 1
        end
    end
    println(found)
    
    # =====================================================
    # BENCHMARK 5: Matrix multiply
    # =====================================================
    dim = 100
    matA = [r + c for r in 0:dim-1, c in 0:dim-1]
    matB = [r - c for r in 0:dim-1, c in 0:dim-1]
    matC = zeros(Int64, dim, dim)
    
    @inbounds for row in 1:dim
        for col in 1:dim
            s = 0
            for k in 1:dim
                s += matA[row,k] * matB[k,col]
            end
            matC[row,col] = s
        end
    end
    println(matC[1,1])
end

# Actually run it
run_benchmarks()