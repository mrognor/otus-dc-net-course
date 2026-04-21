# Underlay. OSPF

## Схема сети
![alt text](lab2.png)

## Конфигурация FRR
На каждом устройстве включены следующие демоны **frr**: ospfd, ospfd6  
Также включен *ospfd-инстанс*: `ospfd_instances=1`

## Настройка системы (Leaf1)
### Linux
*Loopback* настраивается с помощью *dummy-интерфейса*:

```bash
ip link add dev loopback0 type dummy
ip address add 10.0.0.1/32 dev loopback0
```

На линки в сторону спайнов устанавливаются L3-адреса:

```bash
ip address add 10.2.1.1/31 dev eth1
ip address add 10.2.2.1/31 dev eth2
```

### FRR
Каждый интерфейс, помещается в **ospf area0**:

```bash
interface ifname
 ip ospf area 0.0.0.0
```

Устройство должно анонсироваться:

```bash
router ospf 1
 router-id 10.0.0.1
```

Номер `router ospf` должен совпадать с включенным `ospfd_instances`.

Конфигурация остальных устройств находится в директори configs.
