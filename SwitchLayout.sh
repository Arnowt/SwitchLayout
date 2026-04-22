#!/bin/bash

LAYOUT_SWITCH_KEY="${1}"

EN="qwertyuiop[]asdfghjkl;'zxcvbnm,./QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?~\`"
RU="йцукенгшщзхъфывапролджэячсмитьбю.ЙЦУКЕНГШЩЗХЪФЫВАПРОЛДЖЭЯЧСМИТЬБЮ,Ёё"

TMPDIR=$(mktemp -d /tmp/clip-swap.XXXXXX)

# Сохраняем текущий буфер
# Берём список доступных форматов
mapfile -t targets < <(xclip -o -sel clip -t TARGETS 2>/dev/null)

# Приоритет: картинка -> html -> текст
save_target=""
for t in image/png image/jpeg image/bmp text/html UTF8_STRING STRING TEXT; do
    for have in "${targets[@]}"; do
        if [ "$t" = "$have" ]; then save_target="$t"; break 2; fi
    done
done

if [ -n "$save_target" ]; then
    xclip -o -sel clip -t "$save_target" > "$TMPDIR/data" 2>/dev/null
fi

# Функция восстановления при выходе
restore_clipboard() {
    if [ -n "$save_target" ] && [ -s "$TMPDIR/data" ]; then
        # Запускаем xclip полностью отцеплённым, чтобы он жил после скрипта
        # и держал селекшн. setsid + nohup + disown = гарантия.
        setsid nohup xclip -sel clip -t "$save_target" -i "$TMPDIR/data" \
            >/dev/null 2>&1 < /dev/null &
        disown
        # Дадим xclip подхватить селекшн до выхода
        sleep 0.1
    fi
    # TMPDIR не удаляем сразу — xclip читает файл ленью при запросах.
    # Почистим через некоторое время в фоне:
    ( sleep 30; rm -rf "$TMPDIR" ) &
    disown
}
trap restore_clipboard EXIT

# Копируем выделенное
sleep 0.1
echo -n "" | xclip -sel clip
xdotool key --clearmodifiers ctrl+c

input=$(xclip -o -sel clip -t UTF8_STRING 2>/dev/null)
[ -z "$input" ] && exit 0

# Перекодировка раскладки
output=""
for (( i=0; i<${#input}; i++ )); do
    char="${input:$i:1}"
    if [[ "$EN" == *"$char"* ]]; then
        prefix="${EN%%$char*}"; output+="${RU:${#prefix}:1}"
    elif [[ "$RU" == *"$char"* ]]; then
        prefix="${RU%%$char*}"; output+="${EN:${#prefix}:1}"
    else
        output+="$char"
    fi
done

# Вставляем результат
sleep 0.1
echo -n "$output" | xclip -sel clip
xdotool key --clearmodifiers ctrl+v
xdotool key --clearmodifiers "$LAYOUT_SWITCH_KEY"