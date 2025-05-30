function improved_compress()
    % Improved Video Compression with B-frames and Enhanced Quantization
    % GOP Structure: I-B-B-P-B-B-P-... 
    
    % parameters which will be used.
    GOP_SIZE = 15;  % Total frames in GOP (adjustable)
    BLOCK_SIZE = 8;
    
    % Enhanced quantization matrices
    % luminance matrix
    Q_LUMA = [16 11 10 16 24 40 51 61;
              12 12 14 19 26 58 60 55;
              14 13 16 24 40 57 69 56;
              14 17 22 29 51 87 80 62;
              18 22 37 56 68 109 103 77;
              24 35 55 64 81 104 113 92;
              49 64 78 87 103 121 120 101;
              72 92 95 98 112 100 103 99];
    
    % Custom chrominance quantization matrix
    Q_CHROMA = [17 18 24 47 99 99 99 99;
                18 21 26 66 99 99 99 99;
                24 26 56 99 99 99 99 99;
                47 66 99 99 99 99 99 99;
                99 99 99 99 99 99 99 99;
                99 99 99 99 99 99 99 99;
                99 99 99 99 99 99 99 99;
                99 99 99 99 99 99 99 99];
    
    video_dir = './video_data/';
    frame_files = dir(fullfile(video_dir, '*.jpg'));
    num_frames = length(frame_files);
    
    fprintf('Processing %d frames with GOP size %d\n', num_frames, GOP_SIZE);
    
    bitstream = [];
    frame_idx = 1;
    
    while frame_idx <= num_frames
        gop_end = min(frame_idx + GOP_SIZE - 1, num_frames);
        current_gop_size = gop_end - frame_idx + 1;
        
        fprintf('Processing GOP: frames %d to %d\n', frame_idx, gop_end);
        
        % Encoding GOP here
        gop_bitstream = encode_gop_with_b_frames(frame_idx, gop_end, ...
            frame_files, video_dir, Q_LUMA, Q_CHROMA, BLOCK_SIZE);
        
        bitstream = [bitstream gop_bitstream];
        frame_idx = gop_end + 1;
    end
    
    fid = fopen('result_improved.bin', 'wb');
    if fid == -1
        error('Cannot create output file');
    end
    
    % Header information writeen
    fwrite(fid, num_frames, 'uint32');
    fwrite(fid, GOP_SIZE, 'uint32');
    frame = double(imread(fullfile(video_dir, frame_files(1).name)));
    [height, width, ~] = size(frame);
    fwrite(fid, height, 'uint32');
    fwrite(fid, width, 'uint32');
    fwrite(fid, BLOCK_SIZE, 'uint32');
    fwrite(fid, length(bitstream), 'uint32');
    
    %Bitstream written 
    fwrite(fid, bitstream, 'uint8');
    fclose(fid);
    
    fprintf('Compression complete. Output size: %.2f MB\n', ...
        length(bitstream) / (1024*1024));
end

function gop_bitstream = encode_gop_with_b_frames(start_frame, end_frame, ...
    frame_files, video_dir, Q_LUMA, Q_CHROMA, BLOCK_SIZE)

    gop_size = end_frame - start_frame + 1;
    gop_bitstream = [];

    % Load all frames in GOP
    frames = cell(gop_size, 1);
    for i = 1:gop_size
        frame_path = fullfile(video_dir, frame_files(start_frame + i - 1).name);
        frames{i} = double(imread(frame_path));
    end

    frame_types = determine_frame_types(gop_size);
    reconstructed_frames = cell(gop_size, 1);
    gop_frame_bitstreams = cell(gop_size, 1); 

    % First pass: encoding only  I and P frames
    for i = 1:gop_size
        frame_type = frame_types{i};

        if frame_type == 'I'
            fprintf('  Encoding I-frame %d\n', start_frame + i - 1);
            [data, recon] = encode_i_frame(frames{i}, Q_LUMA, Q_CHROMA, BLOCK_SIZE);
            reconstructed_frames{i} = recon;
            gop_frame_bitstreams{i} = [uint8('I') serialize_frame_data(data)];

        elseif frame_type == 'P'
            fprintf('  Encoding P-frame %d\n', start_frame + i - 1);
            ref_idx = find_previous_anchor(i, frame_types);
            if isempty(reconstructed_frames{ref_idx})
                error('Missing reference for P-frame %d (ref idx %d)', i, ref_idx);
            end
            [data, recon] = encode_p_frame(frames{i}, reconstructed_frames{ref_idx}, ...
                Q_LUMA, Q_CHROMA, BLOCK_SIZE);
            reconstructed_frames{i} = recon;
            gop_frame_bitstreams{i} = [uint8('P') serialize_frame_data(data)];
        end
    end

    % Second pass: encode B-frames 
    for i = 1:gop_size
        if frame_types{i} == 'B'
            fprintf('  Encoding B-frame %d\n', start_frame + i - 1);
            [f_idx, b_idx] = find_b_frame_references(i, frame_types);
            if isempty(reconstructed_frames{f_idx}) || isempty(reconstructed_frames{b_idx})
                error('Missing reference(s) for B-frame %d (F: %d, B: %d)', i, f_idx, b_idx);
            end
            [data, recon] = encode_b_frame(frames{i}, ...
                reconstructed_frames{f_idx}, reconstructed_frames{b_idx}, ...
                Q_LUMA, Q_CHROMA, BLOCK_SIZE);
            reconstructed_frames{i} = recon;
            gop_frame_bitstreams{i} = [uint8('B') serialize_frame_data(data)];
        end
    end

    % Concatenation in display order
    for i = 1:gop_size
        gop_bitstream = [gop_bitstream gop_frame_bitstreams{i}];
    end
end

function frame_types = determine_frame_types(gop_size)
    % Creating GOP pattern: I-B-B-P-B-B-P-...
    frame_types = cell(gop_size, 1);
    frame_types{1} = 'I';  
    
    % Pattern: every 3rd frame after I is P, others are B
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
    backward_idx = forward_idx;  
    for i = frame_idx+1:length(frame_types)
        if strcmp(frame_types{i}, 'I') || strcmp(frame_types{i}, 'P')
            backward_idx = i;
            break;
        end
    end
end

function [frame_data, reconstructed] = encode_i_frame(frame, Q_LUMA, Q_CHROMA, BLOCK_SIZE)
    [height, width, channels] = size(frame);
    mb_height = height / BLOCK_SIZE;
    mb_width = width / BLOCK_SIZE;
    
    frame_data = [];
    reconstructed = zeros(size(frame));
    
    for i = 1:mb_height
        for j = 1:mb_width
            row_start = (i-1)*BLOCK_SIZE + 1;
            row_end = i*BLOCK_SIZE;
            col_start = (j-1)*BLOCK_SIZE + 1;
            col_end = j*BLOCK_SIZE;
            
            mb = frame(row_start:row_end, col_start:col_end, :);
            mb_encoded = [];
            mb_reconstructed = zeros(BLOCK_SIZE, BLOCK_SIZE, channels);
            
            for c = 1:channels
                % Select quantization matrix based on channel
                if c == 1  % Luminance (or Red)
                    Q_matrix = Q_LUMA;
                else  % Chrominance (Green/Blue)
                    Q_matrix = Q_CHROMA;
                end
                
                dct_block = dct2(mb(:,:,c));
                
                quantized = round(dct_block ./ Q_matrix);
                
                zigzag_vector = zigzag_scan(quantized);
                rle_data = run_length_encode(zigzag_vector);
                
                mb_encoded = [mb_encoded serialize_rle(rle_data)];
                
                dequantized = quantized .* Q_matrix;
                mb_reconstructed(:,:,c) = idct2(dequantized);
            end
            
            frame_data = [frame_data mb_encoded];
            reconstructed(row_start:row_end, col_start:col_end, :) = mb_reconstructed;
        end
    end
    
    % Clip reconstructed values
    reconstructed = max(0, min(255, reconstructed));
end

function [frame_data, reconstructed] = encode_p_frame(frame, ref_frame, Q_LUMA, Q_CHROMA, BLOCK_SIZE)
    [height, width, channels] = size(frame);
    mb_height = height / BLOCK_SIZE;
    mb_width = width / BLOCK_SIZE;
    
    frame_data = [];
    reconstructed = zeros(size(frame));
    
    for i = 1:mb_height
        for j = 1:mb_width
            row_start = (i-1)*BLOCK_SIZE + 1;
            row_end = i*BLOCK_SIZE;
            col_start = (j-1)*BLOCK_SIZE + 1;
            col_end = j*BLOCK_SIZE;
            
            mb = frame(row_start:row_end, col_start:col_end, :);
            ref_mb = ref_frame(row_start:row_end, col_start:col_end, :);
            
            % residual computation
            residual = mb - ref_mb;
            
            % Processing each color channel
            mb_encoded = [];
            mb_reconstructed = zeros(BLOCK_SIZE, BLOCK_SIZE, channels);
            
            for c = 1:channels
                % Select quantization matrix
                if c == 1
                    Q_matrix = Q_LUMA;
                else
                    Q_matrix = Q_CHROMA;
                end
                
                dct_block = dct2(residual(:,:,c));                
                quantized = round(dct_block ./ Q_matrix);
                zigzag_vector = zigzag_scan(quantized);
                rle_data = run_length_encode(zigzag_vector);
                
                mb_encoded = [mb_encoded serialize_rle(rle_data)];
                
                dequantized = quantized .* Q_matrix;
                reconstructed_residual = idct2(dequantized);
                mb_reconstructed(:,:,c) = ref_mb(:,:,c) + reconstructed_residual;
            end
            
            frame_data = [frame_data mb_encoded];
            reconstructed(row_start:row_end, col_start:col_end, :) = mb_reconstructed;
        end
    end
    

    reconstructed = max(0, min(255, reconstructed));
end

function [frame_data, reconstructed] = encode_b_frame(frame, forward_ref, backward_ref, Q_LUMA, Q_CHROMA, BLOCK_SIZE)
    [height, width, channels] = size(frame);
    mb_height = height / BLOCK_SIZE;
    mb_width = width / BLOCK_SIZE;
    
    frame_data = [];
    reconstructed = zeros(size(frame));
    
    for i = 1:mb_height
        for j = 1:mb_width
            row_start = (i-1)*BLOCK_SIZE + 1;
            row_end = i*BLOCK_SIZE;
            col_start = (j-1)*BLOCK_SIZE + 1;
            col_end = j*BLOCK_SIZE;
            
            mb = frame(row_start:row_end, col_start:col_end, :);
            forward_mb = forward_ref(row_start:row_end, col_start:col_end, :);
            backward_mb = backward_ref(row_start:row_end, col_start:col_end, :);
            

            predicted_mb = (forward_mb + backward_mb) / 2;
            
            residual = mb - predicted_mb;
            
            mb_encoded = [];
            mb_reconstructed = zeros(BLOCK_SIZE, BLOCK_SIZE, channels);
            
            for c = 1:channels
                if c == 1
                    Q_matrix = Q_LUMA;
                else
                    Q_matrix = Q_CHROMA;
                end
                
                dct_block = dct2(residual(:,:,c));
                
                quantized = round(dct_block ./ Q_matrix);
                
                zigzag_vector = zigzag_scan(quantized);
                rle_data = run_length_encode(zigzag_vector);
                
                mb_encoded = [mb_encoded serialize_rle(rle_data)];
                
                dequantized = quantized .* Q_matrix;
                reconstructed_residual = idct2(dequantized);
                mb_reconstructed(:,:,c) = predicted_mb(:,:,c) + reconstructed_residual;
            end
            
            frame_data = [frame_data mb_encoded];
            reconstructed(row_start:row_end, col_start:col_end, :) = mb_reconstructed;
        end
    end
    
    reconstructed = max(0, min(255, reconstructed));
end

function zigzag_vector = zigzag_scan(block)
    zigzag_order = [1 2 6 7 15 16 28 29;
                    3 5 8 14 17 27 30 43;
                    4 9 13 18 26 31 42 44;
                    10 12 19 25 32 41 45 54;
                    11 20 24 33 40 46 53 55;
                    21 23 34 39 47 52 56 61;
                    22 35 38 48 51 57 60 62;
                    36 37 49 50 58 59 63 64];
    
    [~, sort_idx] = sort(zigzag_order(:));
    zigzag_vector = block(sort_idx);
end

function rle_data = run_length_encode(vector)
    rle_data = [];
    i = 1;
    while i <= length(vector)
        current_val = vector(i);
        run_length = 1;
        
        % Count consecutive identical values
        while i + run_length <= length(vector) && vector(i + run_length) == current_val
            run_length = run_length + 1;
        end
        
        rle_data = [rle_data; run_length current_val];
        i = i + run_length;
    end
end

% Convert RLE data to byte stream
function serialized = serialize_rle(rle_data)
    serialized = [];
    for i = 1:size(rle_data, 1)
        run_length = rle_data(i, 1);
        value = rle_data(i, 2);
        
        serialized = [serialized uint8(run_length)];
        
        if value >= 0
            serialized = [serialized typecast(int16(value), 'uint8')];
        else
            serialized = [serialized typecast(int16(value), 'uint8')];
        end
    end
end

function serialized = serialize_frame_data(frame_data)
    data_length = length(frame_data);
    serialized = [typecast(uint32(data_length), 'uint8') frame_data];
end