--creates 10x6 matrix of constant strings to send, to activate each "driver high" of VEMIO2
function create_dh_matrix()
    DH_matrix = {}
    for i = 0, 9, 1 do --columns
        DH_matrix[i] = {}
        for j = 0, 5, 1 do --lines
            if i <= 1 then
                DH_matrix[i][j] = "o25,1"
            elseif i > 1 and i <= 3 then
                DH_matrix[i][j] = "o26,1"
            elseif i > 3 and i <= 5 then
                DH_matrix[i][j] = "o27,1"
            elseif i > 5 and i <= 7 then
                DH_matrix[i][j] = "o28,1"
            elseif i > 7 and i <= 9 then
                DH_matrix[i][j] = "o29,1"
            end
        end
    end
    return DH_matrix
end

--creates 10x6 matrix of constant strings to send, to activate each "driver low" of VEMIO2
function create_dl_matrix()
    DL_matrix = {}
    for i = 0, 9, 1 do          --columns
        DL_matrix[i] = {}
        for j = 0, 5, 1 do      --lines
            if j == 0 then      --bottom (1st) line
                if math.fmod(i, 2) == 0 then    --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o2,1"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o1,1"
                end
            elseif j==1 then --2nd line 
                if math.fmod(i, 2) == 0 then    --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o4,1"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o3,1"
                end
            elseif j==2 then --2nd line 
                if math.fmod(i, 2) == 0 then    --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o6,1"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o5,1"
                end
            elseif j==3 then --2nd line 
                if math.fmod(i, 2) == 0 then    --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o8,1"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o7,1"
                end
            elseif j==4 then --2nd line 
                if math.fmod(i, 2) == 0 then    --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o10,1"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o9,1"
                end
            elseif j==5 then --2nd line 
                if math.fmod(i, 2) == 0 then    --col is even(0;2;4;6...)
                    DL_matrix[i][j] = "o12,1"
                else --col is odd(1;3;5;7...)
                    DL_matrix[i][j] = "o11,1"
                end
            end
        end
    end
    return DL_matrix
end

--concats all elements and prints 2D (ixj) matrix (for debug purpose only)
function print_2D_matrix(matrix)
    matstr = "[\n"
    for j = 5, 0, -1 do
        for i = 0, 9, 1 do
            matstr = matstr .. matrix[i][j] .. " "
        end
        matstr = matstr .. "\n"
    end
    matstr = matstr .. "]"
    print(matstr)
end

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, tonumber(match));
    end
    return result;
end

DH = create_dh_matrix()
DL=create_dl_matrix()

print_2D_matrix(DL)


s = split(io.read(), ",")
print(type(s))
print(type(s[1]))
print(s[2])

count=0
for key, value in pairs(s) do
    print(key..'='..value)
    count=count+1
end
print(count)