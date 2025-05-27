function zz = zigzag_scan(block)
% ZIGZAG_SCAN Converts an 8x8 matrix to a 1x64 vector in zigzag order.
%
%   zz = zigzag_scan(block)
%
%   Input:
%     block - 8x8 matrix (quantized DCT block)
%   Output:
%     zz - 1x64 vector in zigzag order

    if ~isequal(size(block), [8, 8])
        error('Input must be an 8x8 matrix.');
    end

    % Define zigzag index pattern (row-major order)
    zigzag_index = [
         1  2  6  7 15 16 28 29;
         3  5  8 14 17 27 30 43;
         4  9 13 18 26 31 42 44;
        10 12 19 25 32 41 45 54;
        11 20 24 33 40 46 53 55;
        21 23 34 39 47 52 56 61;
        22 35 38 48 51 57 60 62;
        36 37 49 50 58 59 63 64];

    % Convert block to 1x64 using the zigzag index
    zz = block(zigzag_index);
end
