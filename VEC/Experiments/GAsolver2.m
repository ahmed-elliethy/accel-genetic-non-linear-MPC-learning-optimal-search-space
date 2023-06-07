function [uk,cost,pop_size,convergence] = GAsolver2(BSM,xk,lastMV,yref,h,c,n,Ts,uref)
epsilon = .02 ;
convergence = false ;
% Initlize variables
BSMmax = round(max(BSM(1)/1.0472,BSM(1)/4)*400)+10 ;
% BSMmax = 50 ;
if (BSMmax > 250) 
  pop_size = 250 ;
else
  pop_size = BSMmax ;
end
if rem(pop_size, 2) ~= 0
   pop_size = pop_size+1;
end

max_gen = 10; generation = 1; num_vari=c*n;

q = [10000 0  10000 0 100 100]/1000000;
r = [100 1]/1000000;
% Creat the BSM bounds from the last shifted inputs
[lower, upper] = bounds(lastMV,BSM,c,n) ; 
pop_vari = repmat(lower,pop_size,1) + rand(pop_size, c*n).*repmat((upper-lower),pop_size,1);
pop_fitness = calc_fitness(pop_vari,yref,h,c,n,xk,q,r,Ts,uref);
best_obj_record(generation,:) = min(pop_fitness);

while generation < max_gen 
    %------------------------------------
    %parent selection using k-tournament (default k=2) selection
    k = 2;
    temp = randi(pop_size,pop_size,k);
    [~,index] = min(pop_fitness(temp),[],2);
    pop_parent = pop_vari(sum(temp.*(index == 1:k),2),:);
    %------------------------------------
    % crossover (simulated binary crossover): referece[2] 
    % dic_c is the distribution index of crossover 
    % crossover rate is 1
    dis_c = 1;
    mu  = rand(pop_size/2,num_vari);
    parent1 = pop_parent(1:2:pop_size,:);
    parent2 = pop_parent(2:2:pop_size,:);
    beta = 1 + 2*min(min(parent1,parent2)-lower,upper-max(parent1,parent2))./max(abs(parent2-parent1),1E-6);
    alpha = 2 - beta.^(-dis_c-1);
    betaq = (alpha.*mu).^(1/(dis_c+1)).*(mu <= 1./alpha) + (1./(2-alpha.*mu)).^(1/(dis_c+1)).*(mu > 1./alpha);
    % crossover is randomly performed in each variable
    betaq = betaq.*(-1).^randi([0,1],pop_size/2,num_vari);
    offspring1 = 0.5*((1+betaq).*parent1 + (1-betaq).*parent2);
    offspring2 = 0.5*((1-betaq).*parent1 + (1+betaq).*parent2);
    pop_crossover = [offspring1;offspring2];
    %------------------------------------
    % mutation (ploynomial mutation): referece[2] 
    % dis_m is the distribution index of polynomial mutation
    % mutation rate is 1/d
    dis_m = 1;
    pro_m = 1/num_vari;
    rand_var = rand(pop_size,num_vari);
    mu  = rand(pop_size,num_vari);
    deta = min(pop_crossover-lower, upper-pop_crossover)./(upper-lower);
    detaq = zeros(pop_size,num_vari);
    position1 = rand_var<=pro_m & mu<=0.5;
    position2 = rand_var<=pro_m & mu>0.5;
    detaq(position1) = ((2*mu(position1) + (1-2*mu(position1)).*(1-deta(position1)).^(dis_m+1)).^(1/(dis_m+1))-1); 
    detaq(position2) = (1 - (2*(1-mu(position2))+2*(mu(position2)-0.5).*(1-deta(position2)).^(dis_m+1)).^(1/(dis_m+1)));
    pop_mutation = pop_crossover + detaq.*(upper-lower);
    %------------------------------------
    % mutation one calculation
    pop_mutation_fitness = calc_fitness(pop_mutation,yref,h,c,n,xk,q,r,Ts,uref);
    % environment selection11214
    pop_vari_iter = [pop_vari;pop_mutation];
    pop_fitness_iter = [pop_fitness;pop_mutation_fitness];
    [~,win_num] = sort(pop_fitness_iter);
    pop_vari = pop_vari_iter(win_num(1:pop_size),:);
    pop_fitness = pop_fitness_iter(win_num(1:pop_size),:);  
    %------------------------------------
    % update the evaluation number of generation number
    generation = generation + 1;
    best_obj_record(generation,:) = min(pop_fitness);
    if  min(pop_fitness) < epsilon 
        convergence = true ;
        break;
    end
end
uk =  pop_vari(1,:);
cost = min(pop_fitness) ;
end

% fitness function
function f = calc_fitness(pop_vari,yref,h,c,n,xk,q,r,Ts,uref)
p =zeros(height(pop_vari),h*n) ;
p(:,1:(c*n)) = pop_vari ;
% p(:,(c*n)+1:(h*n)) = repmat(pop_vari(:,end-n+1:end),1,h-c);
    f = zeros(height(p),1);
    predicted_state = xk;
    for i = 1:height(p)
      val = 0;
      for j = 1:h
        val = val + ( sum( ((predicted_state(j,:)-yref(j,:)).^2)*q' ) + ...
                      sum( ((p(i,((j-1)*n+1):j*n)-uref(j,:)).^2)*r' ) );
        predicted_state(j+1,:) = getstates(predicted_state(j,:),p(i,((j-1)*n+1):j*n)',Ts);
      end
      f(i) = val ;
    end  
end
% BSM calculation
function [lower, upper] = bounds(lastMV,BS,c,n) 
BSM = repmat(BS,1,c);
lastMV = [lastMV(n+1:end) lastMV(end-(n-1):end)]; 
upper = lastMV+BSM;          
lower = lastMV-BSM ;

 for i=1:n:c*n 
    if upper(i) > pi/6
        upper(i) = pi/6;
    end
    if upper(i+1) > 30
        upper(i+1) = 30;
    end
    if upper(i) < -pi/6
        upper(i) = -pi/6;
    end
    if lower(i+1) < -30
        lower(i+1) = -30;
    end
 end

 
end