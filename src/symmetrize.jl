# symmetrization

act(mon :: SoSMonom, perm :: Dict{Symbol,Symbol}) =
    [ get(perm,k,k) => v for (k,v) in mon ] :: SoSMonom

# XXX currently unused
act(poly :: SoSPoly, perm :: Dict{Symbol,Symbol}) =
    [ act(k,perm) => v for (k,v) in poly ] :: SoSPoly

# maps monomials to their orbits; returns maps in both directions
# note: this is roughly order-preserving, at least to the extent that the first
# monomial given will lie in orbit 1, which is relied on in sossolve().
function monom_orbits(monoms :: Array{SoSMonom}, genperms :: Array{Dict{Symbol,Symbol}})
    ret1 = Dict{SoSMonom,Int64}()
    ret2 = Set{SoSMonom}[]

    orbitidx = 0
    
    seen = Set{SoSMonom}()
    for b in monoms
        if in(b, seen)
            continue
        end
        
        orbitidx += 1
        orbit = Set{SoSMonom}()
        q = SoSMonom[]
        
        # start off with b
        push!(orbit, b)
        push!(q, b)
        
        # explore the orbit
        while !isempty(q)
            c = shift!(q)
            ret1[c] = orbitidx # here's the actual orbit-mapping assignment
            
            # act every possible way on the current element
            for perm in genperms
                i = act(c,perm)
                
                if !in(i,orbit)
                    push!(orbit,i)
                    push!(q,i)
                end
            end
        end

        union!(seen,orbit)
        push!(ret2, orbit)
    end
    
    ret1, ret2
end


symmetrize!(prog :: Program, genperms :: Array{Dict{Symbol,Symbol}}) = append!(prog.symmetries, genperms)
symmetrize!(prog :: Program, genperm :: Dict{Symbol,Symbol}) = push!(prog.symmetries, genperm)

# symmetry according to dihedral group (rotation and reflection)
function symmetrize_dihedral!(prog :: Program, cycles...)
    n = length(cycles[1])

    symmetrize_cyclic!(prog, cycles...)
    
    if n >= 2
        reflect = Dict{Symbol,Symbol}()
        for cycle in cycles
            for i in 1:n
                reflect[cycle[i]] = cycle[n-i+1]
            end
        end
        symmetrize!(prog, reflect)
    end
end

# symmetry according to cyclic group (rotation only)
function symmetrize_cyclic!(prog :: Program, cycles...)
    n = length(cycles[1])
    if n < 2 return end

    rotate = Dict{Symbol,Symbol}()
    for cycle in cycles
        for i in 0:(n-1)
            j = (i+1) % n
            rotate[cycle[i+1]] = cycle[j+1]
        end
    end
    symmetrize!(prog, rotate)
end

# symmetry according to hyperoctahedral group
# warning: bit hacks
function symmetrize_hypercube!(prog :: Program, cubes...)
    n = length(cubes[1])
    if (n & (n - 1)) != 0 # n is not a power of 2
        throw(ArgumentException("argument list in symmetrize_hypercube must be a power of 2"))
    end

    # reflection along first coordinate
    if n >= 2
        refl = [ i => (i$1) for i in 0:(n-1) ] :: Dict{Symbol,Symbol}
        symmetrize!(prog, refl)
    end

    # transposition of first two coordinates
    if n >= 4
        trans = Dict{Symbol,Symbol}()
        for cube in cubes
            for i in 0:(n-1)
                bot = i & 3
                j = (bot == 1 || bot == 2) ? i$3 : i
                trans[cube[i+1]] = cube[j+1]
            end
        end
        symmetrize!(prog, trans)
    end

    # cyclic permutation of all coordinates
    if n >= 8
        cycle = Dict{Symbol,Symbol}()
        for cube in cubes
            for i in 0:(n-1)
                j = i<<1
                if ( (j & n) != 0)
                    j $= n
                    j $= 1
                end
                cycle[cube[i+1]] = cube[j+1]
            end
        end
        symmetrize!(prog, cycle)
    end
end

# symmetry according to full symmetric group
function symmetrize_full!(prog :: Program, symsets...)
    n = length(symsets[1])
    if n < 2 return end
        
    symmetrize!(prog, Dict{Symbol,Symbol}(set[1] => set[2], set[2] => set[1]))

    if n >= 3
        symmetrize_cyclic!(prog, symsets...)
    end
end

