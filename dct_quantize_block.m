function q_block = dct_quantize_block(block, q_matrix)
% DCT_QUANTIZE_BLOCK  Applies 2D DCT and quantization to an 8x8 block.
%
%   q_block = dct_quantize_block(block, q_matrix)
%
%   Inputs:
%     block     - A single 8x8 matrix (grayscale or one channel of RGB).
%     q_matrix  - The 8x8 quantization matrix.
%
%   Output:
%     q_block   - Quantized DCT coefficients (rounded integers).

    % Check input size
    if ~isequal(size(block), [8, 8])
        error('Input block must be 8x8.');
    end

    if ~isequal(size(q_matrix), [8, 8])
        error('Quantization matrix must be 8x8.');
    end

    % Apply 2D Discrete Cosine Transform
    dct_block = dct2(block);

    % Perform element-wise quantization and round the result
    q_block = round(dct_block ./ q_matrix);

end
