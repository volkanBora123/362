function compress(input_dir, output_file, gop_size, q_matrix)
% COMPRESS Encodes a sequence of frames using simplified video compression.
%
%   compress(input_dir, output_file, gop_size, q_matrix)
%
%   Inputs:
%     input_dir   - Directory where input .jpg frames are stored
%     output_file - Name of the binary output file (e.g. 'result.bin')
%     gop_size    - Group of Pictures size (e.g. 10, 15, 30)
%     q_matrix    - 8x8 quantization matrix
    fid = fopen(output_file, 'w');
    if fid == -1
        error('❌ result.bin dosyası açılamadı.');
    else
        disp('✅ result.bin başarıyla açıldı.');
    end

    % ---------------------------
    % 1. Tüm .jpg frame'leri sırayla oku
    % ---------------------------
    files = dir(fullfile(input_dir, '*.jpg'));
    num_frames = length(files);
    
    fprintf('Toplam %d frame bulundu. İşleniyor...\n', num_frames);
    
    % ---------------------------
    % 2. Çıkış dosyasını aç
    % ---------------------------
    fid = fopen(output_file, 'w');
    if fid == -1
        error('Çıkış dosyası açılamadı.');
    end
    
    % ---------------------------
    % 3. Frame'leri sırayla işle
    % ---------------------------
    for i = 1:num_frames
        % a. Frame oku
        img_path = fullfile(input_dir, files(i).name);
        img = imread(img_path);
        img = double(img);  % işleme uygun hale getir
        
        % b. Macroblock'lara ayır
        mb_cells = frame_to_mb(img);  % 45x60 hücre
        
        % c. I-frame mi P-frame mi?
        if mod(i-1, gop_size) == 0
            frame_type = 'I';  % GOP'in ilk frame'i
        else
            frame_type = 'P';  % Predictive frame
        end
        
        % d. Her macroblock'ı sıkıştır
        % (Henüz içini doldurmadık, aşağıda açıklanacak)
        
        % e. frame_type ve veri akışını fwrite ile yaz
    end
    
    % ---------------------------
    % 4. Dosyayı kapat
    % ---------------------------
    fclose(fid);
    fprintf('Sıkıştırma tamamlandı. Çıkış: %s\n', output_file);
end
