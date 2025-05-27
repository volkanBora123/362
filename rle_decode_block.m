function vec = rle_decode_block(rle)
% RLE_DECODE_BLOCK Reconstructs a 1x64 vector from RLE-encoded data.
%
%   vec = rle_decode_block(rle)
%
%   Input:
%     rle - A 2xN matrix:
%           Row 1 = zero run lengths
%           Row 2 = non-zero values
%
%   Output:
%     vec - 1x64 vector (reconstructed)

    if size(rle, 1) ~= 2
        error('RLE input must be a 2-row matrix.');
    end

    vec = [];  % Initialize output

    for i = 1:size(rle, 2)
        run_length = rle(1, i);
        value = rle(2, i);

        % Append zeros and then the value
        vec = [vec, zeros(1, run_length), value];
    end

    % If length is less than 64, pad with trailing zeros
    if length(vec) < 64
        vec = [vec, zeros(1, 64 - length(vec))];
    elseif length(vec) > 64
        warning('Decoded RLE vector is longer than 64 elements. Truncating.');
        vec = vec(1:64);
    end
end
