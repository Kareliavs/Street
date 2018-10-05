%%Configuracion
addpath(genpath('../lib/vlfeat-0.9.17')); vl_setup;
addpath(genpath('../lib/liblinear-1.94/matlab'));
addpath(genpath('../lib/gist'));
addpath(genpath('util'));


config.experiment_id = 'urbanperception';
%data source
config.homedir = '/mnt/raid/data/karelia/urbanperception/';
config.datasource = 'arequipa_experimento';
config.image_url = ['http://localhost:8000/raid/data/karelia/urbanperception/data/images_arequipa/'];
config.image_path = [config.homedir '/data/images_arequipa'];
config.urban_data_file = [config.homedir '/data/consolidated_data_jsonformatted.json'];
config.urban_data_file_type = 'json';

%gist 
config.feature_type = 'gist';
config.gist_features_path = [config.homedir '/output/' config.datasource '/gist_features.mat'];

% Configure Learning parameters for Linear SVMs.
config.splits_path = [config.homedir '/output/split_info/binary'];
ensuredir(config.splits_path);
config.svm_method = Learning.SVM_TYPE('L2_REGULARIZED_L2_LOSS_DUAL');
config.bias_term = 1;
config.split_num = 10;

% output
config.output_path = [config.homedir '/output/' config.datasource];
config.results_path = [config.output_path '/classification_results_' config.feature_type];
ensuredir(config.results_path);

% Load list of cities in the dataset.
cities = UrbanPerception.ListCities();

% Load data from the Place Pulse dataset.
urban = UrbanPerception(config.urban_data_file, config.urban_data_file_type);
%% FEATURES

% Compute or load features.
compute_features_streets;

%% CLASIFICACION

metric_set = {'safer', 'unique', 'upperclass'};
cities_harder = cities{1};%{'Arequipa'};
%Clasificacion
metric_str = metric_set{1}; % si le toca seguridad, singularidad o clase 
city_string ='Arequipa';% cities{1}; %NY
city_string_harder = cities{1};%'Arequipa';
city_identifier = regexprep(lower(city_string), ' ', '_');
ensuredir(sprintf('%s/%s_%s/%s', config.results_path, ...
                      config.experiment_id, city_identifier, metric_str));

    delta_set = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.5];
    delta_aucs = zeros(length(delta_set), config.split_num);
    delta_aucs_harder = zeros(length(delta_set), config.split_num);
    delta = delta_set(1);  % Take the top delta%/bottom delta% as positives/negatives.
        
        %CON QUIEN ENTRENA
        dataset = urban.getBinaryData2(city_string, metric_str, delta);
        [xx, inds] = ismember(dataset.images, urban.data.image_names);
        features_set = feature_matrix(inds, :);
        %CON QUIEN TESTEA
        dataset_harder = urban.getBinaryData(city_string_harder, metric_str, delta);
        [xx, inds_harder] = ismember(dataset_harder.images, urban.data.image_names);
        features_set_harder = feature_matrix(inds_harder, :);
      
        for split_id = 1 : config.split_num % del 1 al 10
            splits_fname = sprintf('%s/split_traincity_%s_metric_%s_d%02d_%02d.mat', ...
                                   config.splits_path, city_identifier, metric_str, ...
                                   round(delta * 100), split_id); %/mnt/raid/data/vicente/urban_release/output/split_info/binary
            if ~exist(splits_fname, 'file') 
                rand('twister', split_id);
                % Load images in trainval, val and test sets.
                data = Learning.CreateRandomizedSplit(dataset.images, dataset.labels, ...
                                                      'classification');
                data_harder = Learning.CreateRandomizedSplit(...
                    dataset_harder.images, dataset_harder.labels, 'classification');
                % Save split data.
                save(splits_fname, 'data', 'data_harder');
            else
                load(splits_fname);
                %data = fix_image_names(data, urban);
                data_harder = fix_image_names(data_harder, urban);
            end
            % Now learn models using Linear SVMs'. IMPORTANTE PARA PREDECIR
            model = Learning.TrainLinearSvm(data, features_set, config); % aprender

            % Now run testing and present results in a webpage.
            test = Learning.TestLinearSvm(data, features_set, model); % testear lo aprendido (data, vector de caracteristicas, modelo)
            %delta_aucs(delta_ind, split_id) = test.area_under_curve;  % auc de cada uno 

            % Now run testing and present results in a webpage.
            test_harder = Learning.TestLinearSvm(data_harder, features_set_harder, model);  % testear lo aprendido con otros
            %delta_aucs_harder(delta_ind, split_id) = test_harder.area_under_curve;

            % Plot output results.
            figure_path = sprintf('%s/%s_%s/%s/delta_%d/%d_pr.jpg', ...
                config.results_path, config.experiment_id, city_identifier, ...
                metric_str, round(100 * delta), split_id); %string
            precisions{1} = test.precisions; precisions{2} = test_harder.precisions;
            recalls{1} = test.recalls; recalls{2} = test_harder.recalls;
            Learning.SavePrecisionRecallCurve(precisions, recalls, figure_path, 'blue');
            f = fopen(sprintf('%s/%s_%s/%s/delta_%d/%d.html', config.results_path, ...
                              config.experiment_id, city_identifier, metric_str, ...
                              round(100 * delta), split_id), 'w');
            fprintf(f, '<html><body><h3>[%s, %s, %s]</h3>\n', config.experiment_id, ...
                       city_identifier, metric_str);
            fprintf(f, '<b>[delta = %.2f, split = %d]</b><br/>\n', delta, split_id);
           % fprintf(f, '<b>[<span style="color:blue"/>AUC_1</span> = %.2f,', ...
           %            test.area_under_curve);%etrenado y probado uno mismo
            %fprintf(f, '<span style="color:red">AUC_2</span> = %.2f]</b><br/>', ...
            %          test_harder.area_under_curve); %entrenado en uno, probado en otro 
            fprintf(f, '<b>[#(train) = %d, #(test) = %d, #(total) = %d]</b><br/>', ...
                    length(data.train_images) + length(data.val_images), ...
                    length(data.test_images), sum(strcmp(urban.data.cities, city_string)));
            fprintf(f, '<img src="%d_pr.jpg"/>', split_id);

            Learning.PlotTestPredictions(f, config, data_harder, test_harder, ...
                                            city_string_harder, 'classification'); %forzado
            Learning.PlotTestPredictions(f, config, data, test, city_string, 'classification'); % si mismos

            fprintf(f, '</body></html>');
            fclose(f);
            
            clear data; clear data_harder;
        end
    %end % resultados totales
    save(sprintf('%s/%s_%s/%s/results.mat', config.results_path, config.experiment_id, ...
                 city_identifier, metric_str), ...
                 'delta_aucs', 'delta_aucs_harder', 'delta_set', ...
                 'config', 'dataset', 'dataset_harder', 'urban');
    ff = fopen(sprintf('%s/%s_%s/%s/results.html', config.results_path, ...
               config.experiment_id, city_identifier, metric_str), 'w');
    fprintf(ff, '<html><body>');
    figure;  hold on; 
    line(delta_set, mean(delta_aucs, 2), 'Color', 'blue'); %verdaderos
    errorbar(delta_set, mean(delta_aucs, 2), std(delta_aucs, 1, 2), ...
             'Marker', 'x', 'MarkerEdgeColor', 'blue', 'LineStyle', ...
             'none', 'Color', [0.6 0.3 0.1]);
    line(delta_set, mean(delta_aucs_harder, 2), 'Color', 'red'); %forzado
    errorbar(delta_set, mean(delta_aucs_harder, 2), std(delta_aucs_harder, 1, 2), ...
             'Marker', 'x', 'MarkerEdgeColor', 'red', 'LineStyle', ...
             'none', 'Color', [0.6 0.3 0.1]);
    axis([0 0.55 0.5 1]);grid;% ejes x y 
    print('-dpng', '-r60', sprintf('%s/%s_%s/%s/results.png', ...
                            config.results_path, config.experiment_id, ...
                            city_identifier, metric_str));
    close;
    fprintf(ff, '<h3>%s_%s_%s</h3>', config.experiment_id, city_identifier, metric_str);
    fprintf(ff, '<img src="results.png"/><br/>');
    fprintf(ff, '<table border>');
    for delta_ind = 1 : length(delta_set)
        delta = delta_set(delta_ind);
        fprintf(ff, '<tr><td><b>delta = %.2f</b></td>', delta);
        for split_id = 1 : config.split_num % 1 a 10
            fprintf(ff, '<td><a href="delta_%d/%d.html">', round(100 * delta), split_id);
            fprintf(ff, '<img src="delta_%d/%d_pr.jpg" height="120"/></a><br/>%.4f</td>', ...
                    round(100 * delta), split_id, delta_aucs(delta_ind, split_id)); % abajo de cada cuadrito. AUCS
        end % promedios 
        fprintf(ff, '<td><br><span style="color:blue">mean(AUC)</span> = %.4f (%.4f)</br>', ...
                     mean(delta_aucs(delta_ind, :)), std(delta_aucs(delta_ind, :)));
        fprintf(ff, '<span style="color:red">mean(AUC)</span> = %.4f (%.4f)</td>', ...
                     mean(delta_aucs_harder(delta_ind, :)), std(delta_aucs_harder(delta_ind, :)));
        fprintf(ff, '</tr>');
    end
    fprintf(ff, '</table>');
    fprintf(ff, '</body></html>');
    fclose(ff); 
%end
%end
%}
