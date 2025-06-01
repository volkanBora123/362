function decompress(GOP_SIZE)
    % Load compressed binary data
    compressed_data = deserialize_from_binary('result.bin');
    
    % Create output directory
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
        
        output_filename = sprintf('./decompressed/frame%03d.jpg', frame_idx);
        imwrite(decompressed_frame_uint8, output_filename);
    end

    fprintf('Decompression complete. Frames saved to ./decompressed/\n');
end

function frame = decompress_i_frame(compressed_frame_data)
    Q = get_quant_matrix();
    [mb_rows, mb_cols, channels] = size(compressed_frame_data);
    frame = zeros(mb_rows * 8, mb_cols * 8, channels);
    
    for ch = 1:channels
        for i = 1:mb_rows
            for j = 1:mb_cols
                rle_data = compressed_frame_data{i, j, ch};
                zz = run_length_decode(rle_data);
                quant_block = inverse_zigzag_scan(zz);
                dct_block = quant_block .* Q;
                block = idct2(dct_block);
                frame((i-1)*8+1:i*8, (j-1)*8+1:j*8, ch) = block;
            end
        end
    end
end

function frame = decompress_p_frame(compressed_frame_data, prev_frame)
    Q = get_quant_matrix();
    [mb_rows, mb_cols, channels] = size(compressed_frame_data);
    frame = zeros(mb_rows * 8, mb_cols * 8, channels);
    
    for ch = 1:channels
        for i = 1:mb_rows
            for j = 1:mb_cols
                rle_data = compressed_frame_data{i, j, ch};
                zz = run_length_decode(rle_data);
                quant_block = inverse_zigzag_scan(zz);
                dct_block = quant_block .* Q;
                residual = idct2(dct_block);
                
                row_start = (i-1)*8 + 1;
                col_start = (j-1)*8 + 1;
                prev_block = prev_frame(row_start:row_start+7, col_start:col_start+7, ch);
                frame(row_start:row_start+7, col_start:col_start+7, ch) = prev_block + residual;
            end
        end
    end
end

function vector = run_length_decode(rle_data)
    vector = [];
    for k = 1:size(rle_data,1)
        count = rle_data(k,1);
        value = rle_data(k,2);
        vector = [vector, repmat(value, 1, count)];
    end
end

function block = inverse_zigzag_scan(zz)
    order = [
         1,  2,  6,  7, 15, 16, 28, 29;
         3,  5,  8, 14, 17, 27, 30, 43;
         4,  9, 13, 18, 26, 31, 42, 44;
        10, 12, 19, 25, 32, 41, 45, 54;
        11, 20, 24, 33, 40, 46, 53, 55;
        21, 23, 34, 39, 47, 52, 56, 61;
        22, 35, 38, 48, 51, 57, 60, 62;
        36, 37, 49, 50, 58, 59, 63, 64
    ];
    block = zeros(8,8);
    for k = 1:64
        [r, c] = find(order == k);
        block(r,c) = zz(k);
    end
end

function Q = get_quant_matrix()
    Q = double([
        16, 11, 10, 16, 24, 40, 51, 61;
        12, 12, 14, 19, 26, 58, 60, 55;
        14, 13, 16, 24, 40, 57, 69, 56;
        14, 17, 22, 29, 51, 87, 80, 62;
        18, 22, 37, 56, 68,109,103, 77;
        24, 35, 55, 64, 81,104,113, 92;
        49, 64, 78, 87,103,121,120,101;
        72, 92, 95, 98,112,100,103, 99
    ]);
end

function data = deserialize_from_binary(filename)
    fid = fopen(filename, 'rb');
    if fid == -1
        error('Cannot open file: %s', filename);
    end
    
    try
        num_frames = fread(fid, 1, 'uint32');
        data = cell(num_frames, 2);
        
        for f = 1:num_frames
            type = fread(fid, 1, 'uint8');
            if type == 0
                data{f,1} = 'I';
            else
                data{f,1} = 'P';
            end
            
            dims = fread(fid, 3, 'uint32');
            mb_rows = dims(1); mb_cols = dims(2); channels = dims(3);
            frame = cell(mb_rows, mb_cols, channels);
            
            for ch = 1:channels
                for i = 1:mb_rows
                    for j = 1:mb_cols
                        num_pairs = fread(fid, 1, 'uint16');
                        rle = zeros(num_pairs, 2);
                        for k = 1:num_pairs
                            rle(k,1) = fread(fid, 1, 'uint8');
                            rle(k,2) = fread(fid, 1, 'int16');
                        end
                        frame{i,j,ch} = rle;
                    end
                end
            end
            data{f,2} = frame;
        end
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    fclose(fid);
end
