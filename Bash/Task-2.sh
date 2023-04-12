if [ -z "$1" ]
then
    echo "Ошибка: не указано имя процесса"
    exit 1
fi

pid=$(pgrep "$1")

if [ -z "$pid" ]
then
    echo "Ошибка: процесс '$1' не найден"
    exit 1
fi

pkill -P "$pid"

if [ $? -eq 0 ]
then
    echo "Процесс '$1' успешно завершен, включая его потомков:"
    pids=$(pgrep -P "$pid")
    echo "$pids"
else
    echo "Ошибка: не удалось завершить процесс '$1'"
    exit 1
fi