% Download images for a city from StreetView.
addpath('util');

% City information and general configuration options.
%config.homedir = '/mnt/raid/data/vicente/urbanperception/';
config.homedir = '/mnt/raid/data/karelia/urbanperception/';

%config.city_id = 'newyork';
config.city_id = 'arequipa';
% Boundaries file are coordinates of a polygon surrounding the city.
% You can create one manually using Google Map Creator and then exporting to KML.
% I have created some myself in the following directory.
%config.boundaries_file = [config.homedir '/data/' config.city_id '/' config.city_id '.coordinates'];
config.boundaries_file = [config.homedir '/data/' config.city_id '/export.kml'];
config.sample_count = 5000;
config.output_dir = [config.homedir '/data'];
config.download_image_dir = [config.homedir '/data/images_' config.city_id];
config.size_str = '640x420';

% Google Street View API configuration.
config.api_key = 'AIzaSyCQGajheBaRe0Vqip4ge1Z3u1HTy0VSJ_Q';  % Get a code from Google Apis.
config.api_url = ['http://maps.googleapis.com/maps/api/streetview?' ...
                  'size=%s&location=%s&sensor=false&key=%s' ...
                  '&heading=%s&fov=%s&pitch=%s'];
config.dummy_image_path = [config.homedir '/data/null_image.jpg'];
ensuredir(config.download_image_dir);

output_data_file = sprintf('%s/%s_data.mat', config.output_dir, config.city_id);
if ~exist(output_data_file, 'file')
    % Read coordinates for the polygon surrounding the city limits.
    coordinates_str = strtrim(fgets(fopen(config.boundaries_file)));
    toks = regexp(coordinates_str, ',', 'split');
    disp(size(toks));
    coordinates_num = cellfun(@(x)eval(x), toks);
    coordinates_num = coordinates_num(1:end-1); % Get rid of Google Maps trailing 0 coordinate.
    longitudes_poly = coordinates_num(1:2:end-1);
    latitudes_poly = coordinates_num(2:2:end);

    % Generate random points inside the lattice.
    left = min(longitudes_poly); right = max(longitudes_poly);
    top = max(latitudes_poly); bottom = min(latitudes_poly);
    height = top - bottom;
    width = right - left;

    rand_vertical = bottom + height .* rand(1, config.sample_count);
    rand_horizontal = left + width .* rand(1, config.sample_count);

    poly_x = [longitudes_poly, longitudes_poly(1)]; 
    poly_y = [latitudes_poly, latitudes_poly(1)];
    disp(size(rand_horizontal));
    disp(size(rand_vertical));
    disp(size(poly_x));
    disp(size(poly_y));
    
    inside = inpolygon(rand_horizontal, rand_vertical, poly_x, poly_y);
    disp(poly_x);
  %  disp(inside);
    %inside = inpolygon(10, 10, 10, 10);
    plot(poly_x, poly_y, 'r.');
    %    plot(poly_x, poly_y, rand_horizontal(inside), rand_vertical(inside), 'r.');


    % Randomly sampled points inside the city of $(config.city_id)
    longitudes = rand_horizontal(inside);
    latitudes = rand_vertical(inside);

    % Now download images from Gooogle Street View.
    is_dummy = false;
    dummy_image = imread(config.dummy_image_path); 
    rand_locs = randperm(length(dummy_image(:)));
    dummy_values = dummy_image(rand_locs(1:200));
    valid_downloads = zeros(1, length(latitudes)); count = 0;
    image_ids = arrayfun(@(x){sprintf('%s%06d', config.city_id, x)}, 1:length(latitudes));
    disp("hola1");
    for i = 1 : length(latitudes)
        disp("hola");
        out_filename = sprintf('%s/%s.jpg', config.download_image_dir, image_ids{i});
        disp(out_filename);
        if ~exist(out_filename, 'file')  
            heading_str = 'NULL'; fov_str = 'NULL'; pitch_str = 'NULL';
            latlong_str = sprintf('%f,%f', latitudes(i), longitudes(i));
            request_url = sprintf(config.api_url, config.size_str, latlong_str, config.api_key, ...
                                  heading_str, fov_str, pitch_str);
            try
                imdata = imread(request_url);
                is_dummy = sum(abs(double(imdata(rand_locs(1:200))) - double(dummy_values))) < 600;
                disp(is_dummy);
                if ~is_dummy
                    imwrite(imdata, out_filename);
                    valid_downloads(i) = 1;
                    pause(0.1);
                    fprintf('%d. Image %s at (%2.5f, %2.5f) downloaded\n', ...
                            i, image_ids{i}, latitudes(i), longitudes(i));
                else
                    fprintf('INVALID IMAGE DETECTED: %d\n', count); count = count + 1;
                end
            catch merror
                fprintf('%d. ERROR WHILE DOWNLOADING IMAGE: %s\n', i, merror.message);
                merror
                pause(1.0);
            end
        end
    end
    image_ids = image_ids(valid_downloads > 0);
    latitudes = latitudes(valid_downloads > 0);
    longitudes = longitudes(valid_downloads > 0);
    save(output_data_file, 'latitudes', 'longitudes', 'image_ids');
else
    fprintf('Data for this city already seems to exist, do not overwrite\n');
end
