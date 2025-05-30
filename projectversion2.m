

% Constants  we will use later on
GOP_SIZE = 30; 
BLOCK_SIZE = 8; 
FRAME_WIDTH = 480;
FRAME_HEIGHT = 360;

% Quantization matrix 
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


function compress()
    GOP_SIZE = 30; 
    
    % Reading  the inputs
    video_path = './video_data/';
    frame_files = dir(fullfile(video_path, '*.jpg'));
    num_frames = length(frame_files);
    
    % Initializing compressed data arrays
    compressed_data = [];
    prev_frame_double = []; 
    
    for frame_idx = 1:num_frames
        % Reading and converting files to double type 
        frame_path = fullfile(video_path, frame_files(frame_idx).name);
        frame_uint8 = imread(frame_path);
        frame = double(frame_uint8); 


        if mod(frame_idx - 1, GOP_SIZE) == 0
            compressed_frame = compress_i_frame(frame);
            frame_type = 'I';
            prev_frame_double = frame; 
        else
            compressed_frame = compress_p_frame(frame, prev_frame_double);
            frame_type = 'P';
            prev_frame_double = frame; 
        end
        
        compressed_data = [compressed_data; {frame_type, compressed_frame}];
    end
    

    serialize_to_binary(compressed_data, 'result.bin');
    
    fprintf('Compression complete. Output saved to result.bin\n');
end

% the function for I-Frame Compression 
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
    [height, width, channels] = size(frame);
    compressed_frame = cell(height/8, width/8, channels);
    
    for ch = 1:channels
        for i = 1:8:height
            for j = 1:8:width
                block = frame(i:i+7, j:j+7, ch);
                dct_block = dct2(block);
                quantized_block = round(dct_block ./ Q_MATRIX);
                zigzag_vector = zigzag_scan(quantized_block);
                rle_data = run_length_encode(zigzag_vector);
                compressed_frame{(i-1)/8+1, (j-1)/8+1, ch} = rle_data;
            end
        end
    end
end

% the function for P-Frame Compression 
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
    [height, width, channels] = size(current_frame);
    compressed_frame = cell(height/8, width/8, channels);
    
    for ch = 1:channels
        for i = 1:8:height
            for j = 1:8:width
                current_block = current_frame(i:i+7, j:j+7, ch);
                prev_block = prev_frame(i:i+7, j:j+7, ch);
                residual_block = current_block - prev_block;
                dct_residual = dct2(residual_block);
                quantized_residual = round(dct_residual ./ double(Q_MATRIX));
                zigzag_vector = zigzag_scan(quantized_residual);
                rle_data = run_length_encode(zigzag_vector);
                compressed_frame{(i-1)/8+1, (j-1)/8+1, ch} = rle_data;
            end
        end
    end
end

% the function for zigzag scanning
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

% this function handles runlength handling
function rle_data = run_length_encode(vector)
    rle_data = [];
    i = 1;
    
    while i <= length(vector)
        current_val = vector(i);
        count = 1;
        while i + count <= length(vector) && vector(i + count) == current_val
            count = count + 1;
        end
        
        rle_data = [rle_data; count, current_val];
        i = i + count;
    end
end

function decompress()
    GOP_SIZE = 30; 
    compressed_data = deserialize_from_binary('result.bin');
    if ~exist('./decompressed/', 'dir')
        mkdir('./decompressed/');
    end
    
    prev_frame_double = [];
    
    for frame_idx = 1:length(compressed_data)
        frame_type = compressed_data{frame_idx, 1};
        compressed_frame_data = compressed_data{frame_idx, 2};
        
        if strcmp(frame_type, 'I')
            decompressed_frame_double = decompress_i_frame(compressed_frame_data);
            prev_frame_double = decompressed_frame_double;
        else
            decompressed_frame_double = decompress_p_frame(compressed_frame_data, prev_frame_double);
            prev_frame_double = decompressed_frame_double; 
        end
        decompressed_frame_clamped = max(0, min(255, decompressed_frame_double));
        decompressed_frame_uint8 = uint8(decompressed_frame_clamped);
        
        output_filename = sprintf('./decompressed/frame_%04d.jpg', frame_idx);
        imwrite(decompressed_frame_uint8, output_filename);
    end
    
    fprintf('Decompression complete. Frames saved to ./decompressed/\n');
end

% I-Frame Decompression 
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
    frame = zeros(mb_rows * 8, mb_cols * 8, channels); 
    
    for ch = 1:channels
        for i = 1:mb_rows
            for j = 1:mb_cols
                rle_data = compressed_frame_data{i, j, ch};
                zigzag_vector = run_length_decode(rle_data);
                quantized_block = inverse_zigzag_scan(zigzag_vector);

                dct_block = quantized_block .* double(Q_MATRIX);
       
                reconstructed_block = idct2(dct_block);

                row_start = (i-1)*8 + 1;
                row_end = i*8;
                col_start = (j-1)*8 + 1;
                col_end = j*8;
                frame(row_start:row_end, col_start:col_end, ch) = reconstructed_block;
            end
        end
    end
end

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

                rle_data = compressed_frame_data{i, j, ch};
                
                zigzag_vector = run_length_decode(rle_data);
                
                quantized_residual = inverse_zigzag_scan(zigzag_vector);
                
                dct_residual = quantized_residual .* double(Q_MATRIX);
                
                reconstructed_residual = idct2(dct_residual);
                
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
    fid = fopen(filename, 'wb');
    if fid == -1
        error('Cannot open file for writing: %s', filename);
    end
    
    try
        num_frames = size(data, 1);
        fwrite(fid, num_frames, 'uint32');
        
        for frame_idx = 1:num_frames
            frame_type = data{frame_idx, 1};
            compressed_frame = data{frame_idx, 2};
            
            if strcmp(frame_type, 'I')
                fwrite(fid, 0, 'uint8');
            else
                fwrite(fid, 1, 'uint8');
            end
            
            [mb_rows, mb_cols, channels] = size(compressed_frame);
            fwrite(fid, [mb_rows, mb_cols, channels], 'uint32');
            
            for ch = 1:channels
                for i = 1:mb_rows
                    for j = 1:mb_cols
                        rle_data = compressed_frame{i, j, ch};
                        
                        num_pairs = size(rle_data, 1);
                        fwrite(fid, num_pairs, 'uint16');
                        
                        for pair_idx = 1:num_pairs
                            count = rle_data(pair_idx, 1);
                            value = rle_data(pair_idx, 2);
                            
                            fwrite(fid, count, 'uint8');
                            
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
    fid = fopen(filename, 'rb');
    if fid == -1
        error('Cannot open file for reading: %s', filename);
    end
    
    try
        num_frames = fread(fid, 1, 'uint32');
        data = cell(num_frames, 2);
        
        for frame_idx = 1:num_frames
            frame_type_code = fread(fid, 1, 'uint8');
            if frame_type_code == 0
                frame_type = 'I';
            else
                frame_type = 'P';
            end
            
            dimensions = fread(fid, 3, 'uint32');
            mb_rows = dimensions(1);
            mb_cols = dimensions(2);
            channels = dimensions(3);
            
            compressed_frame = cell(mb_rows, mb_cols, channels);
            
            for ch = 1:channels
                for i = 1:mb_rows
                    for j = 1:mb_cols
                        num_pairs = fread(fid, 1, 'uint16');
                        
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



function file_size = get_file_size(filename)
    file_info = dir(filename);
    if isempty(file_info)
        file_size = 0;
    else
        file_size = file_info.bytes;
    end
end

function compression_ratio = calculate_compression_ratio(original_size, compressed_size)
    compression_ratio = original_size / compressed_size;
end
% Helper function to get compressed size for a specific GOP size
function compressed_size = get_compressed_size_for_gop(gop_size)
    original_gop = evalin('base', 'GOP_SIZE');
    assignin('base', 'GOP_SIZE', gop_size);
    
    compress();
    
    compressed_size = get_file_size('result.bin') * 8; % Convert to bits
    
    assignin('base', 'GOP_SIZE', original_gop);
end

function psnr_values = compute_psnr_for_gop(gop_size)

    original_gop = evalin('base', 'GOP_SIZE');
    assignin('base', 'GOP_SIZE', gop_size);
    
    compress();
    decompress();
    
    video_path = './video_data/';
    decompressed_path = './decompressed/';
    
    original_files = dir(fullfile(video_path, '*.jpg'));
    decompressed_files = dir(fullfile(decompressed_path, '*.jpg'));
    
    num_frames = length(original_files);
    psnr_values = zeros(1, num_frames);
    
    for i = 1:num_frames
        original_frame = imread(fullfile(video_path, original_files(i).name));
        
        reconstructed_frame = imread(fullfile(decompressed_path, decompressed_files(i).name));
        
        psnr_values(i) = calculate_psnr(double(original_frame), double(reconstructed_frame));
    end
    
    assignin('base', 'GOP_SIZE', original_gop);
end

% This function displays compression statistics
function display_compression_stats(filename)
    compressed_size = get_file_size(filename);
    original_size = 480 * 360 * 3 * 120; % bytes (assuming 120 frames)
    
    fprintf('\n=== Compression Statistics ===\n');
    fprintf('Original size: %.2f MB\n', original_size / (1024*1024));
    fprintf('Compressed size: %.2f MB\n', compressed_size / (1024*1024));
    fprintf('Compression ratio: %.2f:1\n', original_size / compressed_size);
    fprintf('Space savings: %.2f%%\n', (1 - compressed_size/original_size) * 100);
end

function validate_reconstruction()
    fprintf('Validating reconstruction...\n');
    video_path = './video_data/';
    decompressed_path = './decompressed/';
    
    original_files = dir(fullfile(video_path, '*.jpg'));
    decompressed_files = dir(fullfile(decompressed_path, '*.jpg'));
    
    if length(original_files) ~= length(decompressed_files)
        error('Number of original and decompressed frames do not match!');
    end
    
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

% This function combines analysis functions in together
function run_full_analysis()
    fprintf('Starting full compression analysis...\n');
    
    fprintf('\nAnalyzing compression ratios...\n');
    analyze_compression_performance();
    
    fprintf('\nCalculating PSNR curves...\n');
    calculate_psnr_curves();
    
    display_compression_stats('result.bin');
    
    validate_reconstruction();
    
    fprintf('\nAnalysis complete!\n');
end
compress();
decompress();