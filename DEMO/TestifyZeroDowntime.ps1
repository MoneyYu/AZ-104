For($i = 1; $i -le 99999999; $i++)
{
    curl -s -o /dev/null -I -w "%{http_code}\n" https://mctmoney.com/
    $sum += $i
}