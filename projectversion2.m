% Video Compression with DCT and Predictive Coding
% Main implementation framework for the project

% Constants and Configuration
GOP_SIZE = 30; % Group of Pictures size (configurable)
BLOCK_SIZE = 8; % Macroblock size (8x8)
FRAME_WIDTH = 480;
FRAME_HEIGHT = 360;

% Quantization matrix (from Wikipedia JPEG standard) - define as double
Q_MATRIX = double([
    16, 11, 10, 16, 24,  40,  51,  61;
    12, 12, 14, 19, 26,  58,  60,  55;
    14, 13, 16, 24, 40,  57,  69,  56;
    14, 17, 22, 29, 51,  87,  80,  62;
    18, 22, 37, 56, 68,  109, 103, 77;
    24, 35, 55, 64, 81,  104, 113, 92;
    49, 64, 78, 87, 103, 121, 120, 101;
    72, 92, 95, 98, 112, 100, 103, 99
]);

% Zigzag scan pattern for 8x8 blocks
ZIGZAG_ORDER = [
    1,  2,  6,  7,  15, 16, 28, 29;
    3,  5,  8,  14, 17, 27, 30, 43;
    4,  9,  13, 18, 26, 31, 42, 44;
    10, 12, 19, 25, 32, 41, 45, 54;
    11, 20, 24, 33, 40, 46, 53, 55;
    21, 23, 34, 39, 47, 52, 56, 61;
    22, 35, 38, 48, 51, 57, 60, 62;
    36, 37, 49, 50, 58, 59, 63, 64
];

% COMPRESS.M - Main compression function
function compress()
    GOP_SIZE = 30; % Configure GOP size here
    
    % Read input frames
    video_path = './video_data/';
    frame_files = dir(fullfile(video_path, '*.jpg'));
    num_frames = length(frame_files);
    
    % Initialize compressed data structure
    compressed_data = [];
    prev_frame_double = []; % Store previous frame in double precision
    
    for frame_idx = 1:num_frames
        % Read frame as uint8, immediately convert to double
        frame_path = fullfile(video_path, frame_files(frame_idx).name);
        frame_uint8 = imread(frame_path);
        frame = double(frame_uint8); % Convert to double for all processing
        
        % Determine frame type (I-frame or P-frame)
        if mod(frame_idx - 1, GOP_SIZE) == 0
            % I-frame (intra-coded)
            compressed_frame = compress_i_frame(frame);
            frame_type = 'I';
            prev_frame_double = frame; % Store for next P-frame
        else
            % P-frame (predicted) - use stored previous frame in double
            compressed_frame = compress_p_frame(frame, prev_frame_double);
            frame_type = 'P';
            prev_frame_double = frame; % Update for next frame
        end
        
        % Store compressed frame data
        compressed_data = [compressed_data; {frame_type, compressed_frame}];
    end
    
    % Serialize and save to binary file
    serialize_to_binary(compressed_data, 'result.bin');
    
    fprintf('Compression complete. Output saved to result.bin\n');
end

% I-Frame Compression (all processing in double)
function compressed_frame = compress_i_frame(frame)
    Q_MATRIX = double([
        16, 11, 10, 16, 24,  40,  51,  61;
        12, 12, 14, 19, 26,  58,  60,  55;
        14, 13, 16, 24, 40,  57,  69,  56;
        14, 17, 22, 29, 51,  87,  80,  62;
        18, 22, 37, 56, 68,  109, 103, 77;
        24, 35, 55, 64, 81,  104, 113, 92;
        49, 64, 78, 87, 103, 121, 120, 101;
        72, 92, 95, 98, 112, 100, 103, 99
    ]);
    % frame is already in double precision
    [height, width, channels] = size(frame);
    compressed_frame = cell(height/8, width/8, channels);
    
    for ch = 1:channels
        for i = 1:8:height
            for j = 1:8:width
                % Extract 8x8 macroblock (already in double)
                block = frame(i:i+7, j:j+7, ch);
                
                % Apply DCT (input/output in double)
                dct_block = dct2(block);
                
                % Quantize (all operations in double)
                quantized_block = round(dct_block ./ Q_MATRIX);
                
                % Zigzag scan and RLE
                zigzag_vector = zigzag_scan(quantized_block);
                rle_data = run_length_encode(zigzag_vector);
                
                % Store compressed macroblock
                compressed_frame{(i-1)/8+1, (j-1)/8+1, ch} = rle_data;
            end
        end
    end
end

% P-Frame Compression (all processing in double)
function compressed_frame = compress_p_frame(current_frame, prev_frame)
    Q_MATRIX = double([
    16, 11, 10, 16, 24,  40,  51,  61;
    12, 12, 14, 19, 26,  58,  60,  55;
    14, 13, 16, 24, 40,  57,  69,  56;
    14, 17, 22, 29, 51,  87,  80,  62;
    18, 22, 37, 56, 68,  109, 103, 77;
    24, 35, 55, 64, 81,  104, 113, 92;
    49, 64, 78, 87, 103, 121, 120, 101;
    72, 92, 95, 98, 112, 100, 103, 99
    ]);
    % Both frames are already in double precision
    [height, width, channels] = size(current_frame);
    compressed_frame = cell(height/8, width/8, channels);
    
    for ch = 1:channels
        for i = 1:8:height
            for j = 1:8:width
                % Extract 8x8 macroblocks (already in double)
                current_block = current_frame(i:i+7, j:j+7, ch);
                prev_block = prev_frame(i:i+7, j:j+7, ch);
                
                % Compute residual (double precision arithmetic)
                residual_block = current_block - prev_block;
                
                % Apply DCT to residual (input/output in double)
                dct_residual = dct2(residual_block);
                
                % Quantize (all operations in double)
                quantized_residual = round(dct_residual ./ double(Q_MATRIX));
                
                % Zigzag scan and RLE
                zigzag_vector = zigzag_scan(quantized_residual);
                rle_data = run_length_encode(zigzag_vector);
                
                % Store compressed macroblock
                compressed_frame{(i-1)/8+1, (j-1)/8+1, ch} = rle_data;
            end
        end
    end
end

% Zigzag Scanning
function zigzag_vector = zigzag_scan(block)
    ZIGZAG_ORDER = [
        1,  2,  6,  7,  15, 16, 28, 29;
        3,  5,  8,  14, 17, 27, 30, 43;
        4,  9,  13, 18, 26, 31, 42, 44;
        10, 12, 19, 25, 32, 41, 45, 54;
        11, 20, 24, 33, 40, 46, 53, 55;
        21, 23, 34, 39, 47, 52, 56, 61;
        22, 35, 38, 48, 51, 57, 60, 62;
        36, 37, 49, 50, 58, 59, 63, 64
    ];
    zigzag_vector = zeros(1, 64);
    
    for idx = 1:64
        [row, col] = find(ZIGZAG_ORDER == idx);
        zigzag_vector(idx) = block(row, col);
    end
end

% Run-Length Encoding
function rle_data = run_length_encode(vector)
    rle_data = [];
    i = 1;
    
    while i <= length(vector)
        current_val = vector(i);
        count = 1;
        
        % Count consecutive occurrences
        while i + count <= length(vector) && vector(i + count) == current_val
            count = count + 1;
        end
        
        rle_data = [rle_data; count, current_val];
        i = i + count;
    end
end

% DECOMPRESS.M - Main decompression function
function decompress()
    GOP_SIZE = 30; % Configure GOP size here
    
    % Read compressed data
    compressed_data = deserialize_from_binary('result.bin');
    
    % Create output directory
    if ~exist('./decompressed/', 'dir')
        mkdir('./decompressed/');
    end
    
    prev_frame_double = []; % Store previous reconstructed frame in double
    
    for frame_idx = 1:length(compressed_data)
        frame_type = compressed_data{frame_idx, 1};
        compressed_frame_data = compressed_data{frame_idx, 2};
        
        if strcmp(frame_type, 'I')
            % Decompress I-frame
            decompressed_frame_double = decompress_i_frame(compressed_frame_data);
            prev_frame_double = decompressed_frame_double; % Store for next P-frame
        else
            % Decompress P-frame using stored previous frame
            decompressed_frame_double = decompress_p_frame(compressed_frame_data, prev_frame_double);
            prev_frame_double = decompressed_frame_double; % Update for next frame
        end
        
        % Clamp values to valid range [0, 255] and convert to uint8 only for output
        decompressed_frame_clamped = max(0, min(255, decompressed_frame_double));
        decompressed_frame_uint8 = uint8(decompressed_frame_clamped);
        
        % Save frame
        output_filename = sprintf('./decompressed/frame_%04d.jpg', frame_idx);
        imwrite(decompressed_frame_uint8, output_filename);
    end
    
    fprintf('Decompression complete. Frames saved to ./decompressed/\n');
end

% I-Frame Decompression (all processing in double)
function frame = decompress_i_frame(compressed_frame_data)
    Q_MATRIX = double([
        16, 11, 10, 16, 24,  40,  51,  61;
        12, 12, 14, 19, 26,  58,  60,  55;
        14, 13, 16, 24, 40,  57,  69,  56;
        14, 17, 22, 29, 51,  87,  80,  62;
        18, 22, 37, 56, 68,  109, 103, 77;
        24, 35, 55, 64, 81,  104, 113, 92;
        49, 64, 78, 87, 103, 121, 120, 101;
        72, 92, 95, 98, 112, 100, 103, 99
    ]);
    [mb_rows, mb_cols, channels] = size(compressed_frame_data);
    frame = zeros(mb_rows * 8, mb_cols * 8, channels); % Initialize as double
    
    for ch = 1:channels
        for i = 1:mb_rows
            for j = 1:mb_cols
                % Get RLE data
                rle_data = compressed_frame_data{i, j, ch};
                
                % Decode RLE
                zigzag_vector = run_length_decode(rle_data);
                
                % Inverse zigzag scan
                quantized_block = inverse_zigzag_scan(zigzag_vector);
                
                % Dequantize (all operations in double)
                dct_block = quantized_block .* double(Q_MATRIX);
                
                % Inverse DCT (input/output in double)
                reconstructed_block = idct2(dct_block);
                
                % Place in frame (stays in double precision)
                row_start = (i-1)*8 + 1;
                row_end = i*8;
                col_start = (j-1)*8 + 1;
                col_end = j*8;
                frame(row_start:row_end, col_start:col_end, ch) = reconstructed_block;
            end
        end
    end
end

% P-Frame Decompression (all processing in double)
function frame = decompress_p_frame(compressed_frame_data, prev_frame)
    Q_MATRIX = double([
    16, 11, 10, 16, 24,  40,  51,  61;
    12, 12, 14, 19, 26,  58,  60,  55;
    14, 13, 16, 24, 40,  57,  69,  56;
    14, 17, 22, 29, 51,  87,  80,  62;
    18, 22, 37, 56, 68,  109, 103, 77;
    24, 35, 55, 64, 81,  104, 113, 92;
    49, 64, 78, 87, 103, 121, 120, 101;
    72, 92, 95, 98, 112, 100, 103, 99
    ]);
    [mb_rows, mb_cols, channels] = size(compressed_frame_data);
    frame = zeros(mb_rows * 8, mb_cols * 8, channels); % Initialize as double
    
    for ch = 1:channels
        for i = 1:mb_rows
            for j = 1:mb_cols
                % Get RLE data
                rle_data = compressed_frame_data{i, j, ch};
                
                % Decode RLE
                zigzag_vector = run_length_decode(rle_data);
                
                % Inverse zigzag scan
                quantized_residual = inverse_zigzag_scan(zigzag_vector);
                
                % Dequantize (all operations in double)
                dct_residual = quantized_residual .* double(Q_MATRIX);
                
                % Inverse DCT (input/output in double)
                reconstructed_residual = idct2(dct_residual);
                
                % Add to previous frame macroblock (double precision arithmetic)
                row_start = (i-1)*8 + 1;
                row_end = i*8;
                col_start = (j-1)*8 + 1;
                col_end = j*8;
                
                prev_block = prev_frame(row_start:row_end, col_start:col_end, ch);
                reconstructed_block = prev_block + reconstructed_residual;
                
                frame(row_start:row_end, col_start:col_end, ch) = reconstructed_block;
            end
        end
    end
end

% Helper Functions
function vector = run_length_decode(rle_data)
    vector = [];
    for i = 1:size(rle_data, 1)
        count = rle_data(i, 1);
        value = rle_data(i, 2);
        vector = [vector, repmat(value, 1, count)];
    end
end

function block = inverse_zigzag_scan(zigzag_vector)
    % Zigzag scan pattern for 8x8 blocks
    ZIGZAG_ORDER = [
        1,  2,  6,  7,  15, 16, 28, 29;
        3,  5,  8,  14, 17, 27, 30, 43;
        4,  9,  13, 18, 26, 31, 42, 44;
        10, 12, 19, 25, 32, 41, 45, 54;
        11, 20, 24, 33, 40, 46, 53, 55;
        21, 23, 34, 39, 47, 52, 56, 61;
        22, 35, 38, 48, 51, 57, 60, 62;
        36, 37, 49, 50, 58, 59, 63, 64
    ];
    
    block = zeros(8, 8);
    
    for idx = 1:64
        [row, col] = find(ZIGZAG_ORDER == idx);
        block(row, col) = zigzag_vector(idx);
    end
end

function serialize_to_binary(data, filename)
    % Advanced binary serialization for compressed video data
    fid = fopen(filename, 'wb');
    if fid == -1
        error('Cannot open file for writing: %s', filename);
    end
    
    try
        % Write header information
        num_frames = size(data, 1);
        fwrite(fid, num_frames, 'uint32');
        
        for frame_idx = 1:num_frames
            frame_type = data{frame_idx, 1};
            compressed_frame = data{frame_idx, 2};
            
            % Write frame type (I=0, P=1)
            if strcmp(frame_type, 'I')
                fwrite(fid, 0, 'uint8');
            else
                fwrite(fid, 1, 'uint8');
            end
            
            % Get frame dimensions
            [mb_rows, mb_cols, channels] = size(compressed_frame);
            fwrite(fid, [mb_rows, mb_cols, channels], 'uint32');
            
            % Write each macroblock's RLE data
            for ch = 1:channels
                for i = 1:mb_rows
                    for j = 1:mb_cols
                        rle_data = compressed_frame{i, j, ch};
                        
                        % Write number of RLE pairs for this macroblock
                        num_pairs = size(rle_data, 1);
                        fwrite(fid, num_pairs, 'uint16');
                        
                        % Write RLE pairs (count, value)
                        for pair_idx = 1:num_pairs
                            count = rle_data(pair_idx, 1);
                            value = rle_data(pair_idx, 2);
                            
                            % Write count (max 64 for 8x8 block)
                            fwrite(fid, count, 'uint8');
                            
                            % Write value (quantized DCT coefficient, can be negative)
                            fwrite(fid, value, 'int16');
                        end
                    end
                end
            end
        end
        
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    
    fclose(fid);
    fprintf('Data serialized to %s\n', filename);
end

function data = deserialize_from_binary(filename)
    % Advanced binary deserialization for compressed video data
    fid = fopen(filename, 'rb');
    if fid == -1
        error('Cannot open file for reading: %s', filename);
    end
    
    try
        % Read header information
        num_frames = fread(fid, 1, 'uint32');
        data = cell(num_frames, 2);
        
        for frame_idx = 1:num_frames
            % Read frame type
            frame_type_code = fread(fid, 1, 'uint8');
            if frame_type_code == 0
                frame_type = 'I';
            else
                frame_type = 'P';
            end
            
            % Read frame dimensions
            dimensions = fread(fid, 3, 'uint32');
            mb_rows = dimensions(1);
            mb_cols = dimensions(2);
            channels = dimensions(3);
            
            % Initialize compressed frame structure
            compressed_frame = cell(mb_rows, mb_cols, channels);
            
            % Read each macroblock's RLE data
            for ch = 1:channels
                for i = 1:mb_rows
                    for j = 1:mb_cols
                        % Read number of RLE pairs for this macroblock
                        num_pairs = fread(fid, 1, 'uint16');
                        
                        % Read RLE pairs
                        rle_data = zeros(num_pairs, 2);
                        for pair_idx = 1:num_pairs
                            count = fread(fid, 1, 'uint8');
                            value = fread(fid, 1, 'int16');
                            rle_data(pair_idx, :) = [count, value];
                        end
                        
                        compressed_frame{i, j, ch} = rle_data;
                    end
                end
            end
            
            data{frame_idx, 1} = frame_type;
            data{frame_idx, 2} = compressed_frame;
        end
        
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    
    fclose(fid);
    fprintf('Data deserialized from %s\n', filename);
end

%% Utility Functions for Analysis and Debugging

function file_size = get_file_size(filename)
    % Get file size in bytes
    file_info = dir(filename);
    if isempty(file_info)
        file_size = 0;
    else
        file_size = file_info.bytes;
    end
end

function compression_ratio = calculate_compression_ratio(original_size, compressed_size)
    % Calculate compression ratio
    compression_ratio = original_size / compressed_size;
end

function compressed_size = get_compressed_size_for_gop(gop_size)
    % Helper function to get compressed size for a specific GOP size
    % This function would need to be called after running compression
    % with the specified GOP size
    
    % Temporarily modify GOP_SIZE and run compression
    original_gop = evalin('base', 'GOP_SIZE');
    assignin('base', 'GOP_SIZE', gop_size);
    
    % Run compression (you might need to modify this based on your setup)
    compress();
    
    % Get compressed file size
    compressed_size = get_file_size('result.bin') * 8; % Convert to bits
    
    % Restore original GOP_SIZE
    assignin('base', 'GOP_SIZE', original_gop);
end

function psnr_values = compute_psnr_for_gop(gop_size)
    % Compute PSNR values for all frames with specified GOP size
    
    % First, compress and decompress with the specified GOP size
    original_gop = evalin('base', 'GOP_SIZE');
    assignin('base', 'GOP_SIZE', gop_size);
    
    compress();
    decompress();
    
    % Load original and reconstructed frames
    video_path = './video_data/';
    decompressed_path = './decompressed/';
    
    original_files = dir(fullfile(video_path, '*.jpg'));
    decompressed_files = dir(fullfile(decompressed_path, '*.jpg'));
    
    num_frames = length(original_files);
    psnr_values = zeros(1, num_frames);
    
    for i = 1:num_frames
        % Load original frame
        original_frame = imread(fullfile(video_path, original_files(i).name));
        
        % Load reconstructed frame
        reconstructed_frame = imread(fullfile(decompressed_path, decompressed_files(i).name));
        
        % Calculate PSNR
        psnr_values(i) = calculate_psnr(double(original_frame), double(reconstructed_frame));
    end
    
    % Restore original GOP_SIZE
    assignin('base', 'GOP_SIZE', original_gop);
end

function display_compression_stats(filename)
    % Display compression statistics
    compressed_size = get_file_size(filename);
    original_size = 480 * 360 * 3 * 120; % bytes (assuming 120 frames)
    
    fprintf('\n=== Compression Statistics ===\n');
    fprintf('Original size: %.2f MB\n', original_size / (1024*1024));
    fprintf('Compressed size: %.2f MB\n', compressed_size / (1024*1024));
    fprintf('Compression ratio: %.2f:1\n', original_size / compressed_size);
    fprintf('Space savings: %.2f%%\n', (1 - compressed_size/original_size) * 100);
end

function validate_reconstruction()
    % Validate that the reconstruction process works correctly
    fprintf('Validating reconstruction...\n');
    
    % Compare a few random frames
    video_path = './video_data/';
    decompressed_path = './decompressed/';
    
    original_files = dir(fullfile(video_path, '*.jpg'));
    decompressed_files = dir(fullfile(decompressed_path, '*.jpg'));
    
    if length(original_files) ~= length(decompressed_files)
        error('Number of original and decompressed frames do not match!');
    end
    
    % Check first, middle, and last frame
    test_indices = [1, round(length(original_files)/2), length(original_files)];
    
    for idx = test_indices
        original = imread(fullfile(video_path, original_files(idx).name));
        reconstructed = imread(fullfile(decompressed_path, decompressed_files(idx).name));
        
        psnr_val = calculate_psnr(double(original), double(reconstructed));
        fprintf('Frame %d PSNR: %.2f dB\n', idx, psnr_val);
        
        if psnr_val < 20
            warning('Low PSNR detected for frame %d. Check implementation.', idx);
        end
    end
    
    fprintf('Validation complete.\n');
end

% Enhanced Analysis Functions
function run_full_analysis()
    % Run complete analysis for the project
    fprintf('Starting full compression analysis...\n');
    
    % Part 1: Compression ratio analysis
    fprintf('\nAnalyzing compression ratios...\n');
    analyze_compression_performance();
    
    % Part 2: PSNR analysis
    fprintf('\nCalculating PSNR curves...\n');
    calculate_psnr_curves();
    
    % Part 3: Display statistics
    display_compression_stats('result.bin');
    
    % Part 4: Validate reconstruction
    validate_reconstruction();
    
    fprintf('\nAnalysis complete!\n');
end

decompress();