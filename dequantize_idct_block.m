function block = dequantize_idct_block(q_block, q_matrix)
% DEQUANTIZE_IDCT_BLOCK Reconstructs 8x8 block from quantized DCT coefficients.
%
%   block = dequantize_idct_block(q_block, q_matrix)
%
%   Inputs:
%     q_block  - 8x8 matrix of quantized DCT coefficients
%     q_matrix - 8x8 quantization matrix (same used in compression)
%
%   Output:
%     block - Reconstructed 8x8 spatial-domain block

    % Kontrol
    if ~isequal(size(q_block), [8, 8])
        error('Quantized block must be 8x8.');
    end

    if ~isequal(size(q_matrix), [8, 8])
        error('Quantization matrix must be 8x8.');
    end

    % Kuantizasyonu tersine çevir
    dct_block = q_block .* q_matrix;

    % IDCT uygula (Toolbox yoksa kendi idct2.m dosyanı çağırır)
    block = idct2(dct_block);
end
