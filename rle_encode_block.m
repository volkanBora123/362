function rle = rle_encode_block(vec)
% RLE_ENCODE_BLOCK Applies run-length encoding to a 1x64 vector.
%
%   rle = rle_encode_block(vec)
%
%   Input:
%     vec - A 1x64 vector (typically the result of zigzag_scan)
%
%   Output:
%     rle - A 2-row matrix: 
%           Row 1 = run lengths (number of leading zeros before value)
%           Row 2 = non-zero values
%
%   Example:
%     Input:  [12, -3, 0, 0, 0, 5, 0, 0, 0, 0, -1]
%     Output: [0   0   3   4;
%              12 -3   5  -1]
    
        vec = reshape(vec, 1, []);  % Satır vektörü haline getir

    if length(vec) > 64
        error('Input must be at most 64 elements.');
    end

    % Otomatik olarak sıfırlarla doldur
    if length(vec) < 64
        vec = [vec, zeros(1, 64 - length(vec))];
    end


    rle = [];        % Initialize output
    zero_count = 0;  % Counter for consecutive zeros

    for i = 1:length(vec)
        val = vec(i);
        if val == 0
            zero_count = zero_count + 1;
        else
            rle = [rle, [zero_count; val]];  % Append (zero_count, value)
            zero_count = 0;
        end
    end

    % Optionally, you can end with an (end-of-block) marker.
    % But for simplicity, we ignore trailing zeros (as JPEG often does).

end
