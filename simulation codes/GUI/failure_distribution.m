function [failure_distribution] = failure_distribution(States, NumberOfLines)
stable_states = zeros(1, NumberOfLines); %stable_states at (i, 1) represents the number of times that number of lines failed
%for i = 1:length(States(:,1))
for i = 1:length(States)
    
    if States(i,8) == -1
        stable_states(States(i,1)) = stable_states(States(i,1)) + 1; %
    end
    
end

% for i = 1:NumberOfLines
%     if total_states(i) ~= 0
%         
%     end
% end
failure_distribution = stable_states(1, :);
end