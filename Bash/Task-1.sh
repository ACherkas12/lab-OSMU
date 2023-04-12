read -p "Введите имя пользователя: " username

if id "$username" >/dev/null 2>&1; then
    echo "Пользователь $username уже существует"
    exit 1
fi

read -s -p "Введите пароль: " password
echo

read -s -p "Подтвердите пароль: " password_confirm
echo

if [ "$password" != "$password_confirm" ]; then
    echo "Пароли не совпадают"
    exit 1
fi

useradd -m "$username" -s /bin/bash

echo "$username:$password" | chpasswd

echo "export LANG=en_US.UTF-8" >> /home/$username/.bashrc
echo "export LC_ALL=en_US.UTF-8" >> /home/$username/.bashrc

echo "Пользователь $username успешно добавлен в систему"
exit 0