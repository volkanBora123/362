function performance_analysis()
    % Performance Analysis for Improved Video Compression with B-frames
    % This script evaluates compression ratios and PSNR for different GOP sizes
    
    fprintf('=== Performance Analysis: B-frame Algorithm ===\n\n');
    
    % Test different GOP sizes
    gop_sizes = [1, 5, 10, 15, 20, 25, 30];
    
    % Initialize results arrays
    compression_ratios = zeros(size(gop_sizes));
    avg_psnr_values = zeros(size(gop_sizes));
    
    % Original video size calculation
    % 480x360 pixels, 3 channels (RGB), 8 bits per channel, assume 120 frames
    original_size_bits = 480 * 360 * 3 * 8 * 120;
    original_size_bytes = original_size_bits / 8;
    
    fprintf('Original uncompressed size: %.2f MB\n\n', original_size_bytes / (1024*1024));
    
    % Test each GOP size
    for i = 1:length(gop_sizes)
        gop_size = gop_sizes(i);
        fprintf('Testing GOP size: %d\n', gop_size);
        
        % Modify and run compression
        compressed_size = run_compression_test(gop_size);
        
        if compressed_size > 0
            % Calculate compression ratio
            compression_ratios(i) = original_size_bytes / compressed_size;
            
            % Calculate PSNR
            avg_psnr_values(i) = calculate_average_psnr(gop_size);
            
            fprintf('  Compressed size: %.2f MB\n', compressed_size / (1024*1024));
            fprintf('  Compression ratio: %.2f:1\n', compression_ratios(i));
            fprintf('  Average PSNR: %.2f dB\n\n', avg_psnr_values(i));
        else
            fprintf('  Compression failed for GOP size %d\n\n', gop_size);
            compression_ratios(i) = 0;
            avg_psnr_values(i) = 0;
        end
    end
    
    % Generate plots
    generate_performance_plots(gop_sizes, compression_ratios, avg_psnr_values);
    
    % Generate detailed PSNR curves for specific GOP sizes
    generate_psnr_curves([1, 15, 30]);
    
    fprintf('Performance analysis complete!\n');
end

function compressed_size = run_compression_test(gop_size)
    % Run compression with specified GOP size
    try
        % Modify the GOP_SIZE in improved_compress.m and run
        modify_gop_size_and_compress(gop_size);
        
        % Check if output file exists and get its size
        if exist('result_improved.bin', 'file')
            file_info = dir('result_improved.bin');
            compressed_size = file_info.bytes;
        else
            compressed_size = 0;
        end
    catch ME
        fprintf('Error during compression: %s\n', ME.message);
        compressed_size = 0;
    end
end

function modify_gop_size_and_compress(gop_size)
    % Create a temporary version of improved_compress with modified GOP size
    
    % Read the original file
    fid = fopen('improved_compress.m', 'r');
    if fid == -1
        error('Cannot read improved_compress.m');
    end
    
    content = fread(fid, '*char')';
    fclose(fid);
    
    % Replace GOP_SIZE value
    pattern = 'GOP_SIZE = \d+;';
    replacement = sprintf('GOP_SIZE = %d;', gop_size);
    modified_content = regexprep(content, pattern, replacement);
    
    % Write temporary file
    fid = fopen('temp_compress.m', 'w');
    fprintf(fid, '%s', modified_content);
    fclose(fid);
    
    % Run compression
    run('temp_compress.m');
    
    % Clean up
    if exist('temp_compress.m', 'file')
        delete('temp_compress.m');
    end
end

function avg_psnr = calculate_average_psnr(gop_size)
    % Calculate average PSNR by comparing original and decompressed frames
    
    try
        % Run decompression
        modify_gop_size_and_decompress(gop_size);
        
        % Load original and decompressed frames
        original_dir = './video_data/';
        decompressed_dir = './decompressed/';
        
        if ~exist(decompressed_dir, 'dir')
            avg_psnr = 0;
            return;
        end
        
        % Get list of original frames
        original_files = dir(fullfile(original_dir, '*.jpg'));
        psnr_values = [];
        
        for i = 1:min(length(original_files), 120)  % Limit to 120 frames
            % Load original frame
            original_path = fullfile(original_dir, original_files(i).name);
            original_frame = double(imread(original_path));
            
            % Load decompressed frame
            decompressed_filename = sprintf('frame_%04d.jpg', i);
            decompressed_path = fullfile(decompressed_dir, decompressed_filename);
            
            if exist(decompressed_path, 'file')
                decompressed_frame = double(imread(decompressed_path));
                
                % Calculate PSNR
                psnr_val = calculate_psnr(original_frame, decompressed_frame);
                psnr_values = [psnr_values psnr_val];
            end
        end
        
        if ~isempty(psnr_values)
            avg_psnr = mean(psnr_values);
        else
            avg_psnr = 0;
        end
        
    catch ME
        fprintf('Error calculating PSNR: %s\n', ME.message);
        avg_psnr = 0;
    end
end

function modify_gop_size_and_decompress(gop_size)
    % Create and run temporary decompression with modified GOP size
    
    % Read the original file
    fid = fopen('improved_decompress.m', 'r');
    if fid == -1
        error('Cannot read improved_decompress.m');
    end
    
    content = fread(fid, '*char')';
    fclose(fid);
    
    % Replace GOP_SIZE value
    pattern = 'GOP_SIZE = \d+;';
    replacement = sprintf('GOP_SIZE = %d;', gop_size);
    modified_content = regexprep(content, pattern, replacement);
    
    % Write temporary file
    fid = fopen('temp_decompress.m', 'w');
    fprintf(fid, '%s', modified_content);
    fclose(fid);
    
    % Run decompression
    run('temp_decompress.m');
    
    % Clean up
    if exist('temp_decompress.m', 'file')
        delete('temp_decompress.m');
    end
end

function psnr_val = calculate_psnr(original, compressed)
    % Calculate Peak Signal-to-Noise Ratio
    
    % Ensure same dimensions
    if size(original, 3) ~= size(compressed, 3)
        % Convert to grayscale if needed
        if size(original, 3) == 3
            original = rgb2gray(uint8(original));
        end
        if size(compressed, 3) == 3
            compressed = rgb2gray(uint8(compressed));
        end
    end
    
    % Calculate MSE
    mse = mean((original(:) - compressed(:)).^2);
    
    if mse == 0
        psnr_val = Inf;
    else
        % PSNR formula: 20 * log10(MAX_I) - 10 * log10(MSE)
        max_intensity = 255;  % For 8-bit images
        psnr_val = 20 * log10(max_intensity) - 10 * log10(mse);
    end
end

function generate_performance_plots(gop_sizes, compression_ratios, avg_psnr_values)
    % Generate compression ratio and PSNR plots
    
    figure('Position', [100, 100, 1200, 400]);
    
    % Compression ratio plot
    subplot(1, 2, 1);
    plot(gop_sizes, compression_ratios, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
    xlabel('GOP Size');
    ylabel('Compression Ratio');
    title('Compression Ratio vs GOP Size (B-frame Algorithm)');
    grid on;
    
    % Add data labels
    for i = 1:length(gop_sizes)
        if compression_ratios(i) > 0
            text(gop_sizes(i), compression_ratios(i) + 0.1, ...
                sprintf('%.1f', compression_ratios(i)), ...
                'HorizontalAlignment', 'center');
        end
    end
    
    % PSNR plot
    subplot(1, 2, 2);
    plot(gop_sizes, avg_psnr_values, 'r-s', 'LineWidth', 2, 'MarkerSize', 8);
    xlabel('GOP Size');
    ylabel('Average PSNR (dB)');
    title('Average PSNR vs GOP Size (B-frame Algorithm)');
    grid on;
    
    % Add data labels
    for i = 1:length(gop_sizes)
        if avg_psnr_values(i) > 0
            text(gop_sizes(i), avg_psnr_values(i) + 0.5, ...
                sprintf('%.1f', avg_psnr_values(i)), ...
                'HorizontalAlignment', 'center');
        end
    end
    
    % Save plot
    saveas(gcf, 'b_frame_performance_analysis.png');
    fprintf('Performance plots saved as b_frame_performance_analysis.png\n');
end

function generate_psnr_curves(test_gop_sizes)
    % Generate detailed PSNR curves for specific GOP sizes
    
    figure('Position', [200, 200, 800, 600]);
    colors = {'b', 'r', 'g'};
    
    for i = 1:length(test_gop_sizes)
        gop_size = test_gop_sizes(i);
        psnr_curve = calculate_psnr_curve(gop_size);
        
        if ~isempty(psnr_curve)
            plot(1:length(psnr_curve), psnr_curve, colors{i}, ...
                'LineWidth', 2, 'DisplayName', sprintf('GOP Size %d', gop_size));
            hold on;
        end
    end
    
    xlabel('Frame Number');
    ylabel('PSNR (dB)');
    title('PSNR Curves for Different GOP Sizes (B-frame Algorithm)');
    legend('show');
    grid on;
    hold off;
    
    % Save plot
    saveas(gcf, 'b_frame_psnr_curves.png');
    fprintf('PSNR curves saved as b_frame_psnr_curves.png\n');
end

function psnr_curve = calculate_psnr_curve(gop_size)
    % Calculate PSNR for each frame with specified GOP size
    
    try
        % Run compression and decompression
        modify_gop_size_and_compress(gop_size);
        modify_gop_size_and_decompress(gop_size);
        
        % Calculate PSNR for each frame
        original_dir = './video_data/';
        decompressed_dir = './decompressed/';
        
        original_files = dir(fullfile(original_dir, '*.jpg'));
        psnr_curve = [];
        
        for i = 1:min(length(original_files), 120)
            % Load frames
            original_path = fullfile(original_dir, original_files(i).name);
            original_frame = double(imread(original_path));
            
            decompressed_filename = sprintf('frame_%04d.jpg', i);
            decompressed_path = fullfile(decompressed_dir, decompressed_filename);
            
            if exist(decompressed_path, 'file')
                decompressed_frame = double(imread(decompressed_path));
                psnr_val = calculate_psnr(original_frame, decompressed_frame);
                psnr_curve = [psnr_curve psnr_val];
            end
        end
        
    catch ME
        fprintf('Error calculating PSNR curve for GOP size %d: %s\n', gop_size, ME.message);
        psnr_curve = [];
    end
end