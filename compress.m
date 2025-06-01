function compress(GOP_SIZE)
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