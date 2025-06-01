% psnr_analysis.m
% Analyze PSNR vs Frame Number for different GOP sizes

% Define GOP sizes to test
gop_sizes = [1, 15, 30];
num_frames = 120;

% PSNR values: rows = frames, cols = different GOPs
psnr_values = zeros(num_frames, length(gop_sizes));

% Plot config
colors = {'b', 'r', 'g'};
markers = {'o', 's', 'd'};

fprintf('Starting PSNR analysis for GOP sizes: %s\n', mat2str(gop_sizes));

for gop_idx = 1:length(gop_sizes)
    GOP_SIZE = gop_sizes(gop_idx);
    fprintf('\nProcessing GOP size = %d\n', GOP_SIZE);

    % Compress and decompress
    improved_compress(GOP_SIZE); % Change this to compress(GOP_SIZE); for Part 1
    improved_decompress(); % Change this to decompress(GOP_SIZE); for Part 1

    for frame = 1:num_frames
        % --- ORIGINAL FRAME ---
        orig_path = sprintf('./video_data/frame%03d.jpg', frame); 
        if ~isfile(orig_path)
            error('Original frame %03d not found at %s', frame, orig_path);
        end
        orig_frame = imread(orig_path);

        % --- RECONSTRUCTED FRAME ---
        recon_path = sprintf('./decompressed_frames/frame_%04d.jpg', frame); % Change this to './decompressed/ and frame%03d.jpg for Part 1
        if ~isfile(recon_path)
            error('Reconstructed frame %03d not found at %s', frame, recon_path);
        end
        recon_frame = imread(recon_path);

        % PSNR Calculation
        mse = mean((double(orig_frame(:)) - double(recon_frame(:))).^2);
        if mse == 0
            psnr_values(frame, gop_idx) = Inf;
        else
            psnr_values(frame, gop_idx) = 10 * log10((255^2) / mse);
        end

        % Show progress
        if mod(frame, 10) == 0
            fprintf('Frame %04d/120 processed\n', frame); % Change to %03d/120 for Part 1
        end
    end
end

% --- PLOT ---
figure;
hold on;
for gop_idx = 1:length(gop_sizes)
    plot(1:num_frames, psnr_values(:, gop_idx), ...
        [colors{gop_idx} '-' markers{gop_idx}], ...
        'LineWidth', 1.8, ...
        'DisplayName', sprintf('GOP = %d', gop_sizes(gop_idx)));
end

xlabel('Frame Number');
ylabel('PSNR (dB)');
title('PSNR vs Frame Number for Different GOP Sizes for Improved Algorithm');
legend('Location', 'best');
grid on;
set(gca, 'FontSize', 12);
saveas(gcf, 'psnr_plot_improved.png'); % Change this to psnr_plot.png for Part 1

fprintf('\n✅ PSNR analysis complete. Plot saved as psnr_plot_improved.png\n');

% --- AVERAGE PSNR ---
fprintf('\nAverage PSNR per GOP:\n');
for gop_idx = 1:length(gop_sizes)
    avg = mean(psnr_values(:, gop_idx));
    fprintf('GOP = %2d: %.2f dB\n', gop_sizes(gop_idx), avg);
end
