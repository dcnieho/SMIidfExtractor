function out = read_int(fid, n, m, classfun)

if nargin<3 || isempty(m)
    m = 1;
end
if nargin<4
    classfun = @double;
end
[temp,count] = fread(fid, n*m, 'uchar');
if count<n*m
    out = nan;
    return
end
temp = classfun(reshape(temp, n, m));
p = repmat(classfun(2).^classfun(8*(n-1:-1:0))', 1, m);
out = sum(temp .* p, 'native');
end