function improved_decompress()
    % Improved Video Decompression with B-frames and Enhanced Quantization
    
    % Configuration (should match compression settings)
    GOP_SIZE = 15;  % Adjustable - should match compression
    BLOCK_SIZE = 8;
    
    % Enhanced quantization matrices (same as compression)
    Q_LUMA = [16 11 10 16 24 40 51 61;
              12 12 14 19 26 58 60 55;
              14 13 16 24 40 57 69 56;
              14 17 22 29 51 87 80 62;
              18 22 37 56 68 109 103 77;
              24 35 55 64 81 104 113 92;
              49 64 78 87 103 121 120 101;
              72 92 95 98 112 100 103 99];
    
    Q_CHROMA = [17 18 24 47 99 99 99 99;
                18 21 26 66 99 99 99 99;
                24 26 56 99 99 99 99 99;
                47 66 99 99 99 99 99 99;
                99 99 99 99 99 99 99 99;
                99 99 99 99 99 99 99 99;
                99 99 99 99 99 99 99 99;
                99 99 99 99 99 99 99 99];
    
    % Read compressed file
    fid = fopen('result_improved.bin', 'rb');
    if fid == -1
        error('Cannot open compressed file result_improved.bin');
    end
    
    % Read header
    num_frames = fread(fid, 1, 'uint32');
    gop_size_file = fread(fid, 1, 'uint32');
    block_size_file = fread(fid, 1, 'uint32');
    bitstream_length = fread(fid, 1, 'uint32');
    
    fprintf('Decompressing %d frames (GOP size: %d)\n', num_frames, gop_size_file);
    
    % Read bitstream
    bitstream = fread(fid, bitstream_length, 'uint8');
    fclose(fid);
    
    % Create output directory
    output_dir = './decompressed/';
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Decode frames
    decoded_frames = decode_bitstream_with_b_frames(bitstream, num_frames, ...
        gop_size_file, Q_LUMA, Q_CHROMA, BLOCK_SIZE);
    
    % Save decoded frames
    for i = 1:num_frames
        filename = sprintf('frame_%04d.jpg', i);
        filepath = fullfile(output_dir, filename);
        
        % Convert to uint8 and save
        frame_uint8 = uint8(max(0, min(255, decoded_frames{i})));
        imwrite(frame_uint8, filepath);
    end
    
    fprintf('Decompression complete. %d frames saved to %s\n', num_frames, output_dir);
end

function decoded_frames = decode_bitstream_with_b_frames(bitstream, num_frames, ...
    gop_size, Q_LUMA, Q_CHROMA, BLOCK_SIZE)
    
    decoded_frames = cell(num_frames, 1);
    bitstream_pos = 1;
    frame_idx = 1;
    
    while frame_idx <= num_frames
        gop_end = min(frame_idx + gop_size - 1, num_frames);
        current_gop_size = gop_end - frame_idx + 1;
        
        fprintf('Decoding GOP: frames %d to %d\n', frame_idx, gop_end);
        
        % Decode GOP
        [gop_frames, bytes_consumed] = decode_gop_with_b_frames(...
            bitstream(bitstream_pos:end), current_gop_size, ...
            Q_LUMA, Q_CHROMA, BLOCK_SIZE);
        
        % Store decoded frames
        for i = 1:current_gop_size
            decoded_frames{frame_idx + i - 1} = gop_frames{i};
        end
        
        bitstream_pos = bitstream_pos + bytes_consumed;
        frame_idx = gop_end + 1;
    end
end

function [gop_frames, total_bytes_consumed] = decode_gop_with_b_frames(...
    bitstream, gop_size, Q_LUMA, Q_CHROMA, BLOCK_SIZE)
    
    gop_frames = cell(gop_size, 1);
    frame_types = cell(gop_size, 1);
    frame_data = cell(gop_size, 1);
    total_bytes_consumed = 0;
    bitstream_pos = 1;
    
    % First pass: read all frame types and data
    for i = 1:gop_size
        if bitstream_pos > length(bitstream)
            error('Unexpected end of bitstream');
        end
        
        % Read frame type
        frame_type = char(bitstream(bitstream_pos));
        frame_types{i} = frame_type;
        bitstream_pos = bitstream_pos + 1;
        
        % Read frame data length
        if bitstream_pos + 3 > length(bitstream)
            error('Unexpected end of bitstream while reading frame data length');
        end
        
        data_length_bytes = bitstream(bitstream_pos:bitstream_pos+3);
        data_length = typecast(uint8(data_length_bytes), 'uint32');
        bitstream_pos = bitstream_pos + 4;
        
        % Read frame data
        if bitstream_pos + data_length - 1 > length(bitstream)
            error('Unexpected end of bitstream while reading frame data');
        end
        
        frame_data{i} = bitstream(bitstream_pos:bitstream_pos + data_length - 1);
        bitstream_pos = bitstream_pos + data_length;
    end
    
    total_bytes_consumed = bitstream_pos - 1;
    
    % Second pass: decode in proper order (I, P, then B frames)
    % Decode I-frame first
    fprintf('  Decoding I-frame 1\n');
    gop_frames{1} = decode_i_frame(frame_data{1}, Q_LUMA, Q_CHROMA, BLOCK_SIZE);
    
    % Decode P-frames next (they serve as anchors for B-frames)
    for i = 2:gop_size
        if strcmp(frame_types{i}, 'P')
            fprintf('  Decoding P-frame %d\n', i);
            
            % Find reference frame
            ref_idx = find_previous_anchor(i, frame_types);
            
            gop_frames{i} = decode_p_frame(frame_data{i}, gop_frames{ref_idx}, ...
                Q_LUMA, Q_CHROMA, BLOCK_SIZE);
        end
    end
    
    % Finally decode B-frames
    for i = 2:gop_size
        if strcmp(frame_types{i}, 'B')
            fprintf('  Decoding B-frame %d\n', i);
            
            % Find forward and backward references
            [forward_idx, backward_idx] = find_b_frame_references(i, frame_types);
            
            gop_frames{i} = decode_b_frame(frame_data{i}, ...
                gop_frames{forward_idx}, gop_frames{backward_idx}, ...
                Q_LUMA, Q_CHROMA, BLOCK_SIZE);
        end
    end
end

function ref_idx = find_previous_anchor(frame_idx, frame_types)
    % Find the most recent I or P frame
    for i = frame_idx-1:-1:1
        if strcmp(frame_types{i}, 'I') || strcmp(frame_types{i}, 'P')
            ref_idx = i;
            return;
        end
    end
    ref_idx = 1;  % Fallback to I-frame
end

function [forward_idx, backward_idx] = find_b_frame_references(frame_idx, frame_types)
    % Find forward reference (previous I or P frame)
    forward_idx = 1;
    for i = frame_idx-1:-1:1
        if strcmp(frame_types{i}, 'I') || strcmp(frame_types{i}, 'P')
            forward_idx = i;
            break;
        end
    end
    
    % Find backward reference (next I or P frame)
    backward_idx = forward_idx;  % Default to forward reference
    for i = frame_idx+1:length(frame_types)
        if strcmp(frame_types{i}, 'I') || strcmp(frame_types{i}, 'P')
            backward_idx = i;
            break;
        end
    end
end

function decoded_frame = decode_i_frame(frame_data, Q_LUMA, Q_CHROMA, BLOCK_SIZE)
    % Assume standard video dimensions
    height = 360;
    width = 480;
    channels = 3;
    
    decoded_frame = zeros(height, width, channels);
    mb_height = height / BLOCK_SIZE;
    mb_width = width / BLOCK_SIZE;
    
    data_pos = 1;
    
    for i = 1:mb_height
        for j = 1:mb_width
            row_start = (i-1)*BLOCK_SIZE + 1;
            row_end = i*BLOCK_SIZE;
            col_start = (j-1)*BLOCK_SIZE + 1;
            col_end = j*BLOCK_SIZE;
            
            mb_decoded = zeros(BLOCK_SIZE, BLOCK_SIZE, channels);
            
            for c = 1:channels
                % Select quantization matrix
                if c == 1
                    Q_matrix = Q_LUMA;
                else
                    Q_matrix = Q_CHROMA;
                end
                
                % Deserialize RLE data
                [rle_data, bytes_consumed] = deserialize_rle(frame_data(data_pos:end));
                data_pos = data_pos + bytes_consumed;
                
                % Decode RLE
                zigzag_vector = run_length_decode(rle_data);
                
                % Inverse zigzag scan
                quantized_block = inverse_zigzag_scan(zigzag_vector);
                
                % Dequantization
                dequantized = quantized_block .* Q_matrix;
                
                % Inverse DCT
                mb_decoded(:,:,c) = idct2(dequantized);
            end
            
            decoded_frame(row_start:row_end, col_start:col_end, :) = mb_decoded;
        end
    end
    
    % Clip values to valid range
    decoded_frame = max(0, min(255, decoded_frame));
end

function decoded_frame = decode_p_frame(frame_data, ref_frame, Q_LUMA, Q_CHROMA, BLOCK_SIZE)
    [height, width, channels] = size(ref_frame);
    decoded_frame = zeros(height, width, channels);
    mb_height = height / BLOCK_SIZE;
    mb_width = width / BLOCK_SIZE;
    
    data_pos = 1;
    
    for i = 1:mb_height
        for j = 1:mb_width
            row_start = (i-1)*BLOCK_SIZE + 1;
            row_end = i*BLOCK_SIZE;
            col_start = (j-1)*BLOCK_SIZE + 1;
            col_end = j*BLOCK_SIZE;
            
            ref_mb = ref_frame(row_start:row_end, col_start:col_end, :);
            residual_decoded = zeros(BLOCK_SIZE, BLOCK_SIZE, channels);
            
            for c = 1:channels