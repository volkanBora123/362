function improved_decompress()
    % Improved Video Decompression for B-frames and Enhanced Quantization
    % Decodes GOP Structure: I-B-B-P-B-B-P-...
    
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
    %reading all info
    fid = fopen('result_improved.bin', 'rb');
    if fid == -11
        error('Cannot open compressed file: result_improved.bin');
    end

    num_frames = fread(fid, 1, 'uint32');
    GOP_SIZE = fread(fid, 1, 'uint32');
    height = fread(fid, 1, 'uint32');
    width = fread(fid, 1, 'uint32');
    BLOCK_SIZE = fread(fid, 1, 'uint32');
    bitstream_length = fread(fid, 1, 'uint32');

    fprintf('Decompressing %d frames with GOP size %d\n', num_frames, GOP_SIZE);
    fprintf('Frame dimensions: %dx%d, Block size: %d\n', width, height, BLOCK_SIZE);
    fprintf('Bitstream length: %d bytes\n', bitstream_length);

    bitstream = fread(fid, bitstream_length, 'uint8');
    fclose(fid);

    if length(bitstream) ~= bitstream_length
        error('Failed to read complete bitstream. Expected %d bytes, got %d', ...
            bitstream_length, length(bitstream));
    end
    
    % Creating output directory
    output_dir = './decompressed_frames/';
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    frame_idx = 1;
    bitstream_pos = 1;
    
    while frame_idx <= num_frames && bitstream_pos <= length(bitstream)
        gop_end = min(frame_idx + GOP_SIZE - 1, num_frames);
        
        fprintf('Decompressing GOP: frames %d to %d (bitstream pos: %d)\n', ...
            frame_idx, gop_end, bitstream_pos);
        
        [decoded_frames, bitstream_pos] = decode_gop_with_b_frames(...
            bitstream, bitstream_pos, gop_end - frame_idx + 1, ...
            Q_LUMA, Q_CHROMA, BLOCK_SIZE, height, width);
        
        % Saving the  decoded frames
        for i = 1:length(decoded_frames)
            if ~isempty(decoded_frames{i})
                frame_filename = sprintf('frame_%04d.jpg', frame_idx + i - 1);
                frame_path = fullfile(output_dir, frame_filename);                
                frame_uint8 = uint8(round(decoded_frames{i}));
                imwrite(frame_uint8, frame_path);
            end
        end
        
        frame_idx = gop_end + 1;
    end
    
    fprintf('Decompression complete. Frames saved to: %s\n', output_dir);
end

function [decoded_frames, new_pos] = decode_gop_with_b_frames(bitstream, pos, gop_size, Q_LUMA, Q_CHROMA, BLOCK_SIZE, height, width)
    decoded_frames = cell(gop_size, 1);
    frame_types = determine_frame_types(gop_size);
    decoded_flags = false(gop_size, 1);
    b_frame_positions = zeros(gop_size, 1); 
    current_pos = pos;

    % First pass-Decode I and P frames, store B-frame positions
    for i = 1:gop_size
        if current_pos > length(bitstream)
            error('Bitstream position %d exceeds bitstream length %d', ...
                current_pos, length(bitstream));
        end
        frame_type_marker = char(bitstream(current_pos));
        current_pos = current_pos + 1;
        expected_marker = frame_types{i};
        if frame_type_marker ~= expected_marker
            error('Mismatch in expected frame type at position %d. Expected: %s, Found: %s (ASCII: %d)', ...
                i, expected_marker, frame_type_marker, double(bitstream(current_pos-1)));
        end

        fprintf('  Frame %d, type %s, start pos: %d\n', i, frame_type_marker, current_pos-1);

        if strcmp(frame_type_marker, 'I') || strcmp(frame_type_marker, 'P')
            if frame_type_marker == 'I'
                [decoded_frames{i}, current_pos] = decode_i_frame(...
                    bitstream, current_pos, Q_LUMA, Q_CHROMA, BLOCK_SIZE, height, width);
                decoded_flags(i) = true;
            elseif frame_type_marker == 'P'
                ref_idx = find_previous_anchor(i, frame_types);
                if ~decoded_flags(ref_idx)
                    error('Reference frame %d not decoded before P-frame %d.', ref_idx, i);
                end
                [decoded_frames{i}, current_pos] = decode_p_frame(...
                    bitstream, current_pos, decoded_frames{ref_idx}, ...
                    Q_LUMA, Q_CHROMA, BLOCK_SIZE, height, width);
                decoded_flags(i) = true;
            end
        else 
            b_frame_positions(i) = current_pos - 1; % Store position of B-frame marker
            if current_pos + 3 > length(bitstream)
                error('Not enough data to read B-frame length at position %d', current_pos);
            end
            data_length = double(typecast(uint8(bitstream(current_pos:current_pos+3)), 'uint32'));
            current_pos = current_pos + 4 + data_length;
        end
    end

    % Second pass-Decode B-frames using stored positions
    for i = 1:gop_size
        if strcmp(frame_types{i}, 'B')
            if b_frame_positions(i) == 0
                error('No stored position for B-frame %d', i);
            end
            current_pos = b_frame_positions(i);
            if current_pos > length(bitstream)
                error('Bitstream position %d exceeds bitstream length %d', ...
                    current_pos, length(bitstream));
            end
            frame_type_marker = char(bitstream(current_pos));
            current_pos = current_pos + 1;
            expected_marker = frame_types{i};
            if frame_type_marker ~= expected_marker
                error('Mismatch in expected frame type at position %d. Expected: %s, Found: %s (ASCII: %d)', ...
                    current_pos-1, expected_marker, frame_type_marker, double(bitstream(current_pos-1)));
            end

            fprintf('  Decoding B-frame %d', i);
            [forward_idx, backward_idx] = find_b_frame_references(i, frame_types);
            if ~decoded_flags(forward_idx) || ~decoded_flags(backward_idx)
                error('Reference frame(s) for B-frame %d are missing. F: %d, B: %d', ...
                    i, forward_idx, backward_idx);
            end
            [decoded_frames{i}, current_pos] = decode_b_frame(...
                bitstream, current_pos, decoded_frames{forward_idx}, ...
                decoded_frames{backward_idx}, Q_LUMA, Q_CHROMA, BLOCK_SIZE, height, width);
            decoded_flags(i) = true;
        end
    end

    new_pos = current_pos;
end

function frame_types = determine_frame_types(gop_size)
    % Recreate GOP pattern: I-B-B-P-B-B-P-...
    frame_types = cell(gop_size, 1);
    frame_types{1} = 'I';  % First frame is always I    
    for i = 2:gop_size
        if mod(i-1, 3) == 0  
            frame_types{i} = 'P';
        else
            frame_types{i} = 'B';
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
    ref_idx = 1;  
end

function [forward_idx, backward_idx] = find_b_frame_references(frame_idx, frame_types)
    forward_idx = 1;
    for i = frame_idx-1:-1:1
        if strcmp(frame_types{i}, 'I') || strcmp(frame_types{i}, 'P')
            forward_idx = i;
            break;
        end
    end
    
    backward_idx = forward_idx;  
    for i = frame_idx+1:length(frame_types)
        if strcmp(frame_types{i}, 'I') || strcmp(frame_types{i}, 'P')
            backward_idx = i;
            break;
        end
    end
end

function [frame, new_pos] = decode_i_frame(bitstream, pos, Q_LUMA, Q_CHROMA, BLOCK_SIZE, height, width)
    % Checking bounds 
    if pos + 3 > length(bitstream)
        error('Not enough data to read frame length at position %d', pos);
    end
    data_length = double(typecast(uint8(bitstream(pos:pos+3)), 'uint32'));
    pos = pos + 4;
    if pos + data_length - 1 > length(bitstream)
        error('Not enough data for I-frame. Need %d bytes, have %d available', ...
            data_length, length(bitstream) - pos + 1);
    end

    channels = 3;  
    frame = zeros(height, width, channels);
    mb_height = ceil(height / BLOCK_SIZE);
    mb_width = ceil(width / BLOCK_SIZE);
    current_pos = pos;

    try
        for i = 1:mb_height
            for j = 1:mb_width
                row_start = (i-1)*BLOCK_SIZE + 1;
                row_end = min(i*BLOCK_SIZE, height);
                col_start = (j-1)*BLOCK_SIZE + 1;
                col_end = min(j*BLOCK_SIZE, width);
                mb_reconstructed = zeros(BLOCK_SIZE, BLOCK_SIZE, channels);
                for c = 1:channels
                    if c == 1
                        Q_matrix = Q_LUMA;
                    else
                        Q_matrix = Q_CHROMA;
                    end
                    [rle_data, current_pos] = deserialize_rle(bitstream, current_pos);
                    zigzag_vector = run_length_decode(rle_data);
                    if length(zigzag_vector) ~= 64
                        zigzag_vector = [zigzag_vector zeros(1, 64 - length(zigzag_vector))];
                        zigzag_vector = zigzag_vector(1:64);
                    end
                    quantized_block = inverse_zigzag_scan(zigzag_vector);
                    dct_block = quantized_block .* Q_matrix;
                    mb_reconstructed(:,:,c) = idct2(dct_block);
                end
                frame(row_start:row_end, col_start:col_end, :) = mb_reconstructed(1:(row_end-row_start+1), 1:(col_end-col_start+1), :);
            end
        end
    catch ME
        fprintf('Error in I-frame decoding at macroblock (%d,%d): %s\n', i, j, ME.message);
        rethrow(ME);
    end

    frame = max(0, min(255, frame));
    new_pos = current_pos;
end
function [frame, new_pos] = decode_p_frame(bitstream, pos, ref_frame, Q_LUMA, Q_CHROMA, BLOCK_SIZE, height, width)
    if pos + 3 > length(bitstream)
        error('Not enough data to read P-frame length at position %d', pos);
    end
    data_length = double(typecast(uint8(bitstream(pos:pos+3)), 'uint32'));
    pos = pos + 4;
    channels = 3;
    frame = zeros(height, width, channels);
    mb_height = ceil(height / BLOCK_SIZE);
    mb_width = ceil(width / BLOCK_SIZE);
    current_pos = pos;

    for i = 1:mb_height
        for j = 1:mb_width
            row_start = (i-1)*BLOCK_SIZE + 1;
            row_end = min(i*BLOCK_SIZE, height);
            col_start = (j-1)*BLOCK_SIZE + 1;
            col_end = min(j*BLOCK_SIZE, width);
            ref_mb = ref_frame(row_start:row_end, col_start:col_end, :);
            mb_reconstructed = zeros(BLOCK_SIZE, BLOCK_SIZE, channels);
            for c = 1:channels
                if c == 1
                    Q_matrix = Q_LUMA;
                else
                    Q_matrix = Q_CHROMA;
                end
                [rle_data, current_pos] = deserialize_rle(bitstream, current_pos);
                zigzag_vector = run_length_decode(rle_data);
                if length(zigzag_vector) ~= 64
                    zigzag_vector = [zigzag_vector zeros(1, 64 - length(zigzag_vector))];
                    zigzag_vector = zigzag_vector(1:64);
                end
                quantized_block = inverse_zigzag_scan(zigzag_vector);
                dct_block = quantized_block .* Q_matrix;
                residual = idct2(dct_block);
                mb_reconstructed(:,:,c) = ref_mb(:,:,c) + residual(1:(row_end-row_start+1), 1:(col_end-col_start+1));
            end
            frame(row_start:row_end, col_start:col_end, :) = mb_reconstructed(1:(row_end-row_start+1), 1:(col_end-col_start+1), :);
        end
    end

    frame = max(0, min(255, frame));
    new_pos = current_pos;
end

function [frame, new_pos] = decode_b_frame(bitstream, pos, forward_ref, backward_ref, Q_LUMA, Q_CHROMA, BLOCK_SIZE, height, width)
    if pos + 3 > length(bitstream)
        error('Not enough data to read B-frame length at position %d', pos);
    end
    data_length = double(typecast(uint8(bitstream(pos:pos+3)), 'uint32'));
    pos = pos + 4;
    channels = 3;
    frame = zeros(height, width, channels);
    mb_height = ceil(height / BLOCK_SIZE);
    mb_width = ceil(width / BLOCK_SIZE);
    current_pos = pos;

    for i = 1:mb_height
        for j = 1:mb_width
            row_start = (i-1)*BLOCK_SIZE + 1;
            row_end = min(i*BLOCK_SIZE, height);
            col_start = (j-1)*BLOCK_SIZE + 1;
            col_end = min(j*BLOCK_SIZE, width);
            forward_mb = forward_ref(row_start:row_end, col_start:col_end, :);
            backward_mb = backward_ref(row_start:row_end, col_start:col_end, :);
            predicted_mb = (forward_mb + backward_mb) / 2;
            mb_reconstructed = zeros(BLOCK_SIZE, BLOCK_SIZE, channels);
            for c = 1:channels
                if c == 1
                    Q_matrix = Q_LUMA;
                else
                    Q_matrix = Q_CHROMA;
                end
                [rle_data, current_pos] = deserialize_rle(bitstream, current_pos);
                zigzag_vector = run_length_decode(rle_data);
                if length(zigzag_vector) ~= 64
                    zigzag_vector = [zigzag_vector zeros(1, 64 - length(zigzag_vector))];
                    zigzag_vector = zigzag_vector(1:64);
                end
                quantized_block = inverse_zigzag_scan(zigzag_vector);
                dct_block = quantized_block .* Q_matrix;
                residual = idct2(dct_block);
                mb_reconstructed(:,:,c) = predicted_mb(:,:,c) + residual(1:(row_end-row_start+1), 1:(col_end-col_start+1));
            end
            frame(row_start:row_end, col_start:col_end, :) = mb_reconstructed(1:(row_end-row_start+1), 1:(col_end-col_start+1), :);
        end
    end

    frame = max(0, min(255, frame));
    new_pos = current_pos;
end

% Helper functions
function block = inverse_zigzag_scan(zigzag_vector)
    zigzag_order = [1 2 6 7 15 16 28 29;
                    3 5 8 14 17 27 30 43;
                    4 9 13 18 26 31 42 44;
                    10 12 19 25 32 41 45 54;
                    11 20 24 33 40 46 53 55;
                    21 23 34 39 47 52 56 61;
                    22 35 38 48 51 57 60 62;
                    36 37 49 50 58 59 63 64];
    
    [~, sort_idx] = sort(zigzag_order(:));
    block = zeros(8, 8);
    block(sort_idx) = zigzag_vector(1:64);  % Ensure we only use 64 values
end

function vector = run_length_decode(rle_data)
    vector = [];
    for i = 1:size(rle_data, 1)
        run_length = rle_data(i, 1);
        value = rle_data(i, 2);
        vector = [vector repmat(value, 1, run_length)];
    end
end

function [rle_data, new_pos] = deserialize_rle(bitstream, pos)
    rle_data = [];
    current_pos = pos;
    
    % Read until we have processed a complete 8x8 block (64 values)
    total_values = 0;
    
    while total_values < 64 && current_pos + 2 < length(bitstream)
        % Checking bounds
        if current_pos + 2 > length(bitstream)
            warning('Not enough data for complete RLE entry at position %d', current_pos);
            break;
        end
        run_length = double(bitstream(current_pos));
        current_pos = current_pos + 1;
        value_bytes = uint8(bitstream(current_pos:current_pos+1));
        value = double(typecast(value_bytes, 'int16'));
        current_pos = current_pos + 2;

        rle_data = [rle_data; run_length, value];
        total_values = total_values + run_length;
        if size(rle_data, 1) > 64
            warning('RLE data exceeds expected size, truncating');
            break;
        end
    end
    if total_values < 64
        rle_data = [rle_data; 64 - total_values, 0];
    end
    
    new_pos = current_pos;
end