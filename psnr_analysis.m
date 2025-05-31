% psnr_analysis.m
% Analyze PSNR vs Frame Number for different GOP sizes

global GOP_SIZE;

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
    compress;
    decompress;

    for frame = 1:num_frames
        % --- ORIGINAL FRAME ---
        orig_path = sprintf('./video_data/frame%03d.jpg', frame);
        if ~isfile(orig_path)
            error('Original frame %03d not found at %s', frame, orig_path);
        end
        orig_frame = imread(orig_path);

        % --- RECONSTRUCTED FRAME ---
        recon_path = sprintf('./decompressed/frame%03d.jpg', frame);
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
            fprintf('Frame %03d/120 processed\n', frame);
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
title('PSNR vs Frame Number for Different GOP Sizes');
legend('Location', 'best');
grid on;
set(gca, 'FontSize', 12);
saveas(gcf, 'psnr_plot.png');

fprintf('\n✅ PSNR analysis complete. Plot saved as psnr_plot.png\n');

% --- AVERAGE PSNR ---
fprintf('\nAverage PSNR per GOP:\n');
for gop_idx = 1:length(gop_sizes)
    avg = mean(psnr_values(:, gop_idx));
    fprintf('GOP = %2d: %.2f dB\n', gop_sizes(gop_idx), avg);
end
