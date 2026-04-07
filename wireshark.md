# Графическая демонстрация
ctrl shift p

# Отладка пакетов
wireshark -k -i <(sudo ip netns exec clab-lab-t1 tcpdump -U -nni eth1 -w -)
