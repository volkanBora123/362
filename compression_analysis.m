gop_sizes = 1:30;
compression_ratios_original = zeros(size(gop_sizes));
compression_ratios_improved = zeros(size(gop_sizes));
uncompressed_size_bits = 480 * 360 * 24 * 120;

fprintf('Starting compression analysis for %d GOP sizes...\n', length(gop_sizes));

for i = 1:length(gop_sizes)
    GOP_SIZE = gop_sizes(i);  % used in compress.m

    % Display progress
    fprintf('Progress: %2d / %2d (%.0f%%) - Testing GOP size = %d\n', ...
        i, length(gop_sizes), 100 * i / length(gop_sizes), GOP_SIZE);

    % --- ORIGINAL ---
    if isfile('result.bin')
        delete result.bin;
    end
    compress(GOP_SIZE);
    if ~isfile('result.bin')    
        error('result.bin not found after compress');
    end
    original_size = dir('result.bin').bytes;
    compression_ratios_original(i) = uncompressed_size_bits / (8 * original_size);

    % --- IMPROVED ---
    if isfile('result_improved.bin')
        delete result_improved.bin;
    end
    improved_compress(GOP_SIZE);  % Make sure this creates result_improved.bin
    if ~isfile('result_improved.bin')
        error('result_improved.bin not found after improved_compress');
    end
    improved_size = dir('result_improved.bin').bytes;
    compression_ratios_improved(i) = uncompressed_size_bits / (8 * improved_size);
end

% --- Plotting Original Compression Ratio ---
figure;
plot(gop_sizes, compression_ratios_original, 'b-o', 'LineWidth', 2);
xlabel('GOP Size');
ylabel('Compression Ratio');
title('Original Compression Ratio vs GOP Size');
grid on;
set(gca, 'FontSize', 12);

% Save Original plot
saveas(gcf, 'compression_ratio_original.png');

% --- Plotting Improved Compression Ratio ---
figure;
plot(gop_sizes, compression_ratios_improved, 'r-s', 'LineWidth', 2);
xlabel('GOP Size');
ylabel('Compression Ratio');
title('Improved Compression Ratio vs GOP Size');
grid on;
set(gca, 'FontSize', 12);

% Save Improved plot
saveas(gcf, 'compression_ratio_improved.png');

fprintf('Compression analysis complete. Plots saved as:\n');
fprintf('   - compression_ratio_original.png\n');
fprintf('   - compression_ratio_improved.png\n');
