function block = inverse_zigzag(vec)
% INVERSE_ZIGZAG Converts a 1x64 vector back to an 8x8 matrix.
%
%   block = inverse_zigzag(vec)
%
%   Input:
%     vec - A 1x64 vector (e.g., output of RLE + zigzag)
%   Output:
%     block - An 8x8 matrix reconstructed in zigzag pattern

    if ~isequal(size(vec), [1, 64])
        error('Input must be a 1x64 row vector.');
    end

    % Zigzag index matrix (row-wise)
    zigzag_index = [
         1  2  6  7 15 16 28 29;
         3  5  8 14 17 27 30 43;
         4  9 13 18 26 31 42 44;
        10 12 19 25 32 41 45 54;
        11 20 24 33 40 46 53 55;
        21 23 34 39 47 52 56 61;
        22 35 38 48 51 57 60 62;
        36 37 49 50 58 59 63 64];

    % Invert the zigzag
    block = zeros(8, 8);
    block(zigzag_index) = vec;
end
