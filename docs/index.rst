.. Single vxlan device documentation master file, created by
   sphinx-quickstart on Mon Jun 15 18:11:05 2026.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Сравнение моделей vxlan устройств в ядре Linux
==============================================

Актуальный :strong:`frr` поддерживает обе модели, и ему не важно как будет настроено
:strong:`ядро`.

Traditional vxlan device
------------------------

Multiple bridge
~~~~~~~~~~~~~~~

:strong:`Frr` поддерживает мультбриджовую настройку.
При таком подходе бридж будет играть роль :emphasis:`SVI-интерфейса`.
А вместо добавления интерфейса к пользователю в vlan, надо
добавлять его в бридж.

.. code-block:: bash

    # Vni 10010 - vlan 10
    ip link add dev br10 type bridge
    ip address add 192.168.10.254/24 dev br10
    ip link set dev br10 up
    ip link add vni-10010 type vxlan local 1.1.1.1 dstport 4789 id 10010 nolearning
    ip link set vni-10010 master br10
    ip link set vni-10010 up

    # Vni 10020 - vlan 20
    ip link add dev br20 type bridge
    ip address add 192.168.20.254/24 dev br20
    ip link set dev br20 up
    ip link add vni-10020 type vxlan local 1.1.1.1 dstport 4789 id 10020 nolearning
    ip link set vni-10020 master br20
    ip link set vni-10020 up

Так как :emphasis:`vni-vlan` маппинг идет один к одному, а в такой схеме на каждый :emphasis:`vlan`
создается бридж, то и для каждого маппинга нужен свой :emphasis:`vxlan-интерфейс`.

Single bridge
~~~~~~~~~~~~~

Другим вариантом является использование одного бриджа в режиме
``vlan_filter``. В этом режиме бридж будет использовать фильтрацию по :emphasis:`vlan`,
т.е. пакеты не будут пересылаться между разными :emphasis:`vlan` в рамках коммутации пакетов.
Это важно, чтобы пакеты между разными :emphasis:`vni` могли только маршрутизироваться

.. code-block:: bash

    # Bridge
    ip link add dev br0 type bridge
    ip link set dev br0 type bridge vlan_filter 1 vlan_default_pvid 0
    bridge vlan add dev br0 vid 10 self
    bridge vlan add dev br0 vid 20 self
    ip link set dev br0 up

Так как бридж в такой схеме один, нужно создавать отдельные :emphasis:`SVI-интерфейсы`
для каждого :emphasis:`vlan`:

.. code-block:: bash

    # Svi 10
    ip link add link br0 dev vlan10 type vlan id 10
    ip address add 192.168.10.254/24 dev vlan10
    ip link set dev vlan10 up

    # Svi 20
    ip link add link br0 dev vlan20 type vlan id 20
    ip address add 192.168.20.254/24 dev vlan20
    ip link set dev vlan20 up

В традиционной модели :emphasis:`vxlan` каждый :emphasis:`vni-vlan` маппинг требует отдельного
:emphasis:`vxlan` интерфейса:

.. code-block:: bash

    # Vxlan 10
    ip link add vni-10010 type vxlan local 1.1.1.1 dstport 4789 id 10010 nolearning
    ip link set vni-10010 master br0
    bridge vlan del vid 1 dev vni-10010
    bridge vlan add vid 10 dev vni-10010
    ip link set vni-10010 up


    ip link add vni-10020 type vxlan local 1.1.1.1 dstport 4789 id 10020 nolearning
    ip link set vni-10020 master br0
    bridge vlan del vid 1 dev vni-10020
    bridge vlan add vid 20 dev vni-10020
    ip link set vni-10020 up

Такой интерфейс должен находиться в бридже в своем :emphasis:`vlan`. Он выполняет функцию
энкапсуляции пакетов. Например, :emphasis:`bum-трафик`, входящий в бридж, попадет на :emphasis:`vxlan-интерфейс`.
Там он обернется в обычный :emphasis:`ip-пакет` и будет отправлен на другие :emphasis:`vtep` с помощью :emphasis:`RT-3` маршрутов.

Single vxlan device
-------------------

Режим одного :emphasis:`vxlan-устройства` предполагает использование всего одного интерфейса.
Такая модель значительно ближе к вендорским прошивкам, и компактнее в плане настройки.

При создании :emphasis:`vxlan-интерфейса` нужно указать две дополнительные опции:
``external`` и ``vnifilter``. Первая обязательна, а вторая нет, но
с ней будет корректнее.
Также для интерфейса нужно включить ``vlan_tunnel``.

.. code-block:: bash

    # Bridge
    ip link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0
    ip link add vxlan0 type vxlan dstport 4789 local 1.1.1.1 nolearning external vnifilter
    ip link set br0 up
    ip link set vxlan0 up
    bridge link set dev vxlan0 vlan_tunnel on

:emphasis:`Svi` все также нужен

.. code-block:: bash

    # Vlan 10
    ip link add vlan10 link br0 type vlan id 10
    ip addr add 192.168.10.254/24 dev vlan10
    ip link set vlan10 up

    # Vlan 20
    ip link add vlan20 link br0 type vlan id 20
    ip addr add 192.168.20.254/24 dev vlan20
    ip link set vlan20 up

Для установки маппинга между :emphasis:`vni` и :emphasis:`vlan` нужно:
1. Добавить бридж в :emphasis:`vlan`, чтобы пакеты могли выйти из него для маршрутизации
2. Добавить :emphasis:`vxlan-интерфейс` в :emphasis:`vlan`
3. Добавить :emphasis:`vxlan-интерфейс` в :emphasis:`vni`
4. Установить :emphasis:`vni-vlan` маппинг для :emphasis:`vxlan-интерфейса`

.. code-block:: bash

    # l2vni 110 - vlan 10
    bridge vlan add dev br0 vid 10 self
    bridge vlan add dev vxlan0 vid 10
    bridge vni add dev vxlan0 vni 110
    bridge vlan add dev vxlan0 vid 10 tunnel_info id 110

    # l2vni 120 - vlan 20
    bridge vlan add dev br0 vid 20 self
    bridge vlan add dev vxlan0 vid 20
    bridge vni add dev vxlan0 vni 120
    bridge vlan add dev vxlan0 vid 20 tunnel_info id 120

Примеры конфигурации топологий
------------------------------

Асимметричный irb
~~~~~~~~~~~~~~~~~

Топология
"""""""""

.. uml::

    @startditaa
                                                                         00:00:00:01:00:02     
                                                                        192.168.10.2/24        
                                                                      default gw 192.168.10.253
                                                                              +----+           
                                                                              |    |           
                       loopback0 1.1.1.1                  loopback0 2.2.2.2   | T2 |           
                      SVI10 192.168.10.254                SVI10 192.168.10.253|    |           
                        00:00:00:10:00:01                   00:00:00:10:00:02 +-+--+           
                      SVI20 192.168.20.254                SVI20 192.168.20.253  |              
                        00:00:00:20:00:01                   00:00:00:20:00:02   |              
                           +-----+                             +-----+eth2      |ingress       
                           |     |                             |     +----------+pvid 10       
          ingress+---------+ SW1 +-----------------------------+ SW2 |                         
          pvid 10|     eth2|     |eth1                     eth1|     +----------+ingress       
                 |         +-----+10.0.0.0             10.0.0.1+-----+eth3      |pvid 20       
                 |            00:00:00:00:01:01   00:00:00:00:01:02             |              
                 |                                                              |              
              +--+-+                                                          +-+--+           
              |    |                                                          |    |           
              | T1 |                                                          | T3 |           
              |    |                                                          |    |           
              +----+                                                          +----+           
     00:00:00:01:00:01                                                   00:00:00:01:00:03     
       192.168.10.1/24                                                  192.168.20.1/24        
    default gw 192.168.10.254                                         default gw 192.168.20.253
    @endditaa

С помощью данной топологии будет продемонстрирована :emphasis:`маршрутизация` и :emphasis:`коммутация` с помощью vxlan.

* Для :emphasis:`T1` и :emphasis:`T2`, находящихся в одном vlan, пакет будет коммутироваться
* Для :emphasis:`T1` и :emphasis:`T2`, находящихся в разных vlan, пакет будет маршрутизироваться

Настройка FRR
"""""""""""""

.. tabs::

   .. tab:: SW1

        .. code-block:: bash

            router bgp 65000
             neighbor 10.0.0.1 remote-as internal
             !
             address-family ipv4 unicast
              network 1.1.1.1/32
             exit-address-family
             !
             address-family l2vpn evpn
              neighbor 10.0.0.1 activate
              advertise-all-vni
             exit-address-family
            exit
            !
            end

   .. tab:: SW2

        .. code-block:: bash

            router bgp 65000
             neighbor 10.0.0.0 remote-as internal
             !
             address-family ipv4 unicast
              network 2.2.2.2/32
             exit-address-family
             !
             address-family l2vpn evpn
              neighbor 10.0.0.0 activate
              advertise-all-vni
             exit-address-family
            exit
            !
            end

:emphasis:`Bgp` используется как для :emphasis:`overlay-сети`, так и для :emphasis:`underlay-сети`.
Для упрощения настраивается :strong:`ibgp`, но разницы с :strong:`ebgp` не будет.

Оба устройства:

* Находятся в :emphasis:`AS 65000`
* Анонсируют свои :emphasis:`loopback-адреса` в :emphasis:`underlay-сети`
* Отсылают все свои :emphasis:`vni`

На этом настройка :strong:`frr` заканчивается. Для старой модели :emphasis:`traditional vxlan device`
конфигурация не отличается.

Настройка Linux
"""""""""""""""

.. tabs::

   .. tab:: SW1

        .. code-block:: bash

            # Loopback
            ip link add dev loopback0 type dummy
            ip addr add 1.1.1.1/32 dev loopback0
            ip link set loopback0 up

            # Underlay
            ip link set dev eth1 address 00:00:00:00:01:01
            ip address add 10.0.0.0/31 dev eth1

            # Bridge
            ip link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0
            ip link add vxlan0 type vxlan dstport 4789 local 1.1.1.1 nolearning external vnifilter
            ip link set vxlan0 master br0
            ip link set br0 up
            ip link set vxlan0 up
            bridge link set dev vxlan0 vlan_tunnel on

            # l2vni 110 - vlan 10
            bridge vlan add dev br0 vid 10 self
            bridge vlan add dev vxlan0 vid 10
            bridge vni add dev vxlan0 vni 110
            bridge vlan add dev vxlan0 vid 10 tunnel_info id 110
            ip link add vlan10 link br0 type vlan id 10
            ip addr add 192.168.10.254/24 dev vlan10
            ip link set vlan10 up

            # l2vni 120 - vlan 20
            bridge vlan add dev br0 vid 20 self
            bridge vlan add dev vxlan0 vid 20
            bridge vni add dev vxlan0 vni 120
            bridge vlan add dev vxlan0 vid 20 tunnel_info id 120
            ip link add vlan20 link br0 type vlan id 20
            ip addr add 192.168.20.254/24 dev vlan20
            ip link set vlan20 up

            # Client link
            ip link set dev eth2 master br0
            bridge vlan add vid 10 dev eth2 pvid 10 egress untagged

   .. tab:: SW2

        .. code-block:: bash

            # Loopback
            ip link add dev loopback0 type dummy
            ip addr add 2.2.2.2/32 dev loopback0
            ip link set loopback0 up

            # Underlay
            ip link set dev eth1 address 00:00:00:00:01:02
            ip address add 10.0.0.1/31 dev eth1

            # Bridge
            ip link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0
            ip link add vxlan0 type vxlan dstport 4789 local 2.2.2.2 nolearning external vnifilter
            ip link set vxlan0 master br0
            ip link set br0 up
            ip link set vxlan0 up
            bridge link set dev vxlan0 vlan_tunnel on

            # l2vni 110 - vlan 10
            bridge vlan add dev br0 vid 10 self
            bridge vlan add dev vxlan0 vid 10
            bridge vni add dev vxlan0 vni 110
            bridge vlan add dev vxlan0 vid 10 tunnel_info id 110
            ip link add vlan10 link br0 type vlan id 10
            ip addr add 192.168.10.253/24 dev vlan10
            ip link set vlan10 up

            # l2vni 120 - vlan 20
            bridge vlan add dev br0 vid 20 self
            bridge vlan add dev vxlan0 vid 20
            bridge vni add dev vxlan0 vni 120
            bridge vlan add dev vxlan0 vid 20 tunnel_info id 120
            ip link add vlan20 link br0 type vlan id 20
            ip addr add 192.168.20.253/24 dev vlan20
            ip link set vlan20 up

            # Client links
            ip link set dev eth2 master br0
            bridge vlan add vid 10 dev eth2 pvid 10 egress untagged

            ip link set dev eth3 master br0
            bridge vlan add vid 20 dev eth3 pvid 20 egress untagged

   .. tab:: T1

        .. code-block:: bash

            ip link set dev eth1 address 00:00:00:01:00:01
            ip addr add 192.168.10.1/24 dev eth1

            ip route replace default via 192.168.10.254 dev eth1

   .. tab:: T2

        .. code-block:: bash

            ip link set dev eth1 address 00:00:00:01:00:02
            ip addr add 192.168.10.2/24 dev eth1

            ip route replace default via 192.168.10.253 dev eth1

   .. tab:: T3

        .. code-block:: bash

            ip link set dev eth1 address 00:00:00:01:00:03
            ip addr add 192.168.20.1/24 dev eth1

            ip route replace default via 192.168.20.253 dev eth1

:strong:`Loopback` интерфейс нужен для анонсирования :strong:`RT-3 маршрутов`.
Для распространения RT=3 маршрутов можно использовать и физический линк,
но в таком случае устройство сможет построить evpn-связность только на этом линке.
:strong:`Frr` анонсирует ip-адрес loopback-интерфейса в :emphasis:`underlay`,
а на других vtep этот адрес будет использоваться как next-hop для энкапсулированного пакета.

Для :strong:`underlay` интерфейсов используется :strong:`p2p` адресация, что позволяет
экономить адресное пространство.

:strong:`Bridge` должен быть сконфигурирован в режиме ``vlan_filtering 1``.
Это нужно, чтобы внутри бриджа пакеты учитывали vlan при коммутации и пакеты между
разными vni могли только маршрутизироваться.

При создании :strong:`Vxlan` интерфейса указывается ip-адрес, он будет использоваться
в качестве src-ip в :emphasis:`underlay` пакете.

:strong:`Svi` интерфейсы для каждого :emphasis:`vlan` нужны, чтобы пакеты могли
выйти из бриджа на маршрутизацию. После чего пакет будет отправлен на svi другого
vlan, попадут в этот же бридж, но уже в другой vlan и будут отправлены по vxlan-туннелю.

Перед настройкой :strong:`vni-vlan mapping` нужно добавить vni и vlan на интерфейс.

Состояние стенда
""""""""""""""""

В frr :strong:`RT-3` маршрут устанавливается на каждый vni, каждым vtep.
Поэтому, их будет 4 штуки. Два с локального vtep для vni 110 и 120 и
два с удаленного vtep для тех же vlan.

.. tabs::

   .. tab:: SW1

        .. code-block:: ini

            sw1# show bgp l2vpn evpn route type 3
            BGP table version is 2, local router ID is 192.168.20.254
            Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
            Origin codes: i - IGP, e - EGP, ? - incomplete
            EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
            EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
            EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
            EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
            EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

            Network          Next Hop            Metric LocPrf Weight Path
                                Extended Community
            Route Distinguisher: 192.168.20.253:2
            *>i [3]:[0]:[32]:[2.2.2.2]
                                2.2.2.2                       100      0 i
                                RT:65000:120 ET:8
            Route Distinguisher: 192.168.20.253:3
            *>i [3]:[0]:[32]:[2.2.2.2]
                                2.2.2.2                       100      0 i
                                RT:65000:110 ET:8
            Route Distinguisher: 192.168.20.254:2
            *>  [3]:[0]:[32]:[1.1.1.1]
                                1.1.1.1                            32768 i
                                ET:8 RT:65000:120
            Route Distinguisher: 192.168.20.254:3
            *>  [3]:[0]:[32]:[1.1.1.1]
                                1.1.1.1                            32768 i
                                ET:8 RT:65000:110

            Displayed 4 prefixes (4 paths) (of requested type)

   .. tab:: SW2

        .. code-block:: ini

            sw2# show bgp l2vpn evpn route type 3
            BGP table version is 3, local router ID is 192.168.20.253
            Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
            Origin codes: i - IGP, e - EGP, ? - incomplete
            EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
            EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
            EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
            EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
            EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

            Network          Next Hop            Metric LocPrf Weight Path
                                Extended Community
            Route Distinguisher: 192.168.20.253:2
            *>  [3]:[0]:[32]:[2.2.2.2]
                                2.2.2.2                            32768 i
                                ET:8 RT:65000:120
            Route Distinguisher: 192.168.20.253:3
            *>  [3]:[0]:[32]:[2.2.2.2]
                                2.2.2.2                            32768 i
                                ET:8 RT:65000:110
            Route Distinguisher: 192.168.20.254:2
            *>i [3]:[0]:[32]:[1.1.1.1]
                                1.1.1.1                       100      0 i
                                RT:65000:120 ET:8
            Route Distinguisher: 192.168.20.254:3
            *>i [3]:[0]:[32]:[1.1.1.1]
                                1.1.1.1                       100      0 i
                                RT:65000:110 ET:8

            Displayed 4 prefixes (4 paths) (of requested type)

В ядре RT-3 реализованы через специальную запись в :emphasis:`fdb-таблице`
с маком ``00:00:00:00:00:00`` и ip удаленного vtep.

.. tabs::

   .. tab:: SW1

        .. code-block:: bash

            sw1:~# bridge fdb show
            00:00:00:00:00:00 dev vxlan0 dst 2.2.2.2 src_vni 120 self permanent
            00:00:00:00:00:00 dev vxlan0 dst 2.2.2.2 src_vni 110 self permanent

   .. tab:: SW2

        .. code-block:: bash

            sw2:~# bridge fdb show
            00:00:00:00:00:00 dev vxlan0 dst 1.1.1.1 src_vni 120 self permanent
            00:00:00:00:00:00 dev vxlan0 dst 1.1.1.1 src_vni 110 self permanent

:strong:`RT-2` маршруты появятся только после начала общения между устройствами.

Коммутация
""""""""""

Прохождение BUM-трафика
***********************

Для демонстрации коммутации будет отправлен пакет от :strong:`T1` к
:strong:`T2`, так как эти клиенты находятся в одном vlan. Здесь будет
разобран :strong:`arp-запрос`.

.. code-block:: bash
    
    ping -c 1 192.168.10.2

Клиент сгенерирует следующий пакет:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.10.2"

Он придет на интерфейс :emphasis:`eth2` :strong:`SW1`. Там к пакету добавится :emphasis:`vlan-метка`
с vid 10. Пакет с меткой попадет в бридж:

.. mermaid ::

    packet-beta

    0-31: "802.1Q VLAN ID - 10"
    +16: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.10.2"

Это бродкаст пакет, т.е. бридж отправит его во все порты, кроме того, с которого он прилетел.
В текущей схеме в бридже есть еще один интерфейс - :strong:`vxlan0`.
Пакет попадет на vxlan0, будет энкапсулирован в vxlan пакет и отправлен на все
другие vtep, анонсирующие RT-3 маршрут в этом же vni.
Ip-адреса других vtep будут получаться из специальных записей fdb-таблицы с маками
``00:00:00:00:00:00`` и ip. В качестве ip-адреса источника будет адрес, указанный при
создании :emphasis:`vxlan-устройства`.
Так будет сформирована первая часть :emphasis:`underlay-пакета`:

.. mermaid ::

    packet-beta

    0-15: "Underlay source MAC - XX:XX:XX:XX:XX:XX"
    +16: "Underlay destination MAC - XX:XX:XX:XX:XX:XX"
    +16: "Underlay source IP - 1.1.1.1"
    +16: "Underlay destination IP - 2.2.2.2"
    +16: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.10.2"
    +32: "Vni - 110"

Чтобы отправить пакет на ip-адрес удаленного vtep, используется таблица маршрутизации:

.. code-block:: bash
    
    sw1:~# ip route show
    2.2.2.2 nhid 12 via 10.0.0.1 dev eth1 proto bgp metric 20

Для этого пакета next-hop'ом будет underlay-порт удаленного vtep, поэтому
для получения мака назначение будет использована arp-таблица:

.. code-block:: bash

    sw1 ~ ip neigh show
    10.0.0.1 dev eth1 lladdr 00:00:00:00:01:02 REACHABLE

А в качестве MAC отправителя будет взят MAC интерфейса :emphasis:`eth1`: ``00:00:00:00:01:01``.

Тогда underlay-пакет будет выглядеть так:

.. mermaid ::

    packet-beta

    0-15: "Underlay source MAC - 00:00:00:00:01:01"
    +16: "Underlay destination MAC - 00:00:00:00:01:02"
    +16: "Underlay source IP - 1.1.1.1"
    +16: "Underlay destination IP - 2.2.2.2"
    +16: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.10.2"
    +32: "Vni - 110"

На :strong:`SW2` underlay-пакет попадет на порт :emphasis:`eth1`. MAC-адрес назначения совпадает
с MAC-адресом интерфейса, поэтому пакет поднимется для маршрутизации. Ip-адрес назначения
совпадает с адресом vxlan-интерфейса и пакет попадет на него. Vxlan-интерфейс декапсулирует пакет
и добавит к нему vlan-тег, на основании :emphasis:`vni-vlan` маппинга.

В бридж попадет следующий пакет:

.. mermaid ::

    packet-beta

    0-31: "802.1Q VLAN ID - 10"
    +16: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.10.2"

Этот пакет будет отправлен на все порты в 10 vlan, кроме
vxlan0, т.е. на eth2. При выходе из eth2 будет снят vlan-тег.
Клиент :strong:`T2` получит обычный пакет, который был послан :emphasis:`T1`:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.10.2"

После прохождения этого пакета на свичах появится RT-2 запись с маком :emphasis:`T1`:

.. tabs::

   .. tab:: SW1

        .. code-block:: ini

            sw1# show bgp l2vpn evpn route type 2 
            BGP table version is 2, local router ID is 192.168.20.254
            Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
            Origin codes: i - IGP, e - EGP, ? - incomplete
            EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
            EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
            EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
            EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
            EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

            Network          Next Hop            Metric LocPrf Weight Path
                                Extended Community
            Route Distinguisher: 192.168.20.254:3
            *>  [2]:[0]:[48]:[00:00:00:01:00:01]
                                1.1.1.1                            32768 i
                                ET:8 RT:65000:110

            Displayed 1 prefixes (1 paths) (of requested type)

   .. tab:: SW2

        .. code-block:: ini

            sw2# show bgp l2vpn evpn route type 2 
            BGP table version is 2, local router ID is 192.168.20.253
            Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
            Origin codes: i - IGP, e - EGP, ? - incomplete
            EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
            EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
            EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
            EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
            EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

            Network          Next Hop            Metric LocPrf Weight Path
                                Extended Community
            Route Distinguisher: 192.168.20.254:3
            *>i [2]:[0]:[48]:[00:00:00:01:00:01]
                                1.1.1.1                       100      0 i
                                RT:65000:110 ET:8

            Displayed 1 prefixes (1 paths) (of requested type)

Прохождение unicast-трафика
***************************

Unicast трафик будет разобран на примере arp-ответа на запрос из предыдущей главы.
После того, как :strong:`T2` получил arp-запрос, он отправит следующий ответ:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:01:00:02"
    +16: "Destination MAC - 00:00:00:01:00:01"
    +16: "Source IP - 192.168.10.2"
    +16: "Destination IP - 192.168.10.1"

Пакет придет на интерфейс :emphasis:`eth2` :strong:`SW2`. Там к пакету добавится :emphasis:`vlan-метка`
с vid 10. После он попадет в бридж:

.. mermaid ::

    packet-beta

    0-31: "802.1Q VLAN ID - 10"
    +16: "Source MAC - 00:00:00:01:00:02"
    +16: "Destination MAC - 00:00:00:01:00:01"
    +16: "Source IP - 192.168.10.2"
    +16: "Destination IP - 192.168.10.1"

Т.к это не :emphasis:`broacast` запрос, ядро проверит fdb-таблицу:

.. code-block:: bash

    sw2 ~ bridge fdb show
    00:00:00:01:00:01 dev vxlan0 dst 1.1.1.1 src_vni 110 self extern_learn

В fdb-таблице находится запись с нужным маком, которую туда добавил frr из-за RT-2 маршрута.
Поэтому пакет будет отправлен на интерфейс vxlan0. Там он будет энкапсулирован также, как и при
отправке bum-трафика. В underlay изменений не будет.

После декапсуляции пакета на :strong:`SW1` он попадет в бридж, где будет еще одна проверка fdb-таблицы:

.. code-block:: bash

    sw1 ~ bridge fdb show
    00:00:00:01:00:01 dev eth2 vlan 10 master br0

После чего пакет будет скоммутирован на интерфейс :emphasis:`eth2`

:strong:`T1` получит исходный пакет

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:01:00:02"
    +16: "Destination MAC - 00:00:00:01:00:01"
    +16: "Source IP - 192.168.10.2"
    +16: "Destination IP - 192.168.10.1"

Маршрутизация
"""""""""""""

Прохождение BUM-трафика
***********************

Для передачи пакетов между разными vlan на клиентах указывается маршрут
по умолчанию через :emphasis:`svi-интерфейс` ближайшего свича.

Для демонстрации коммутации будет отправлен пакет от :strong:`T1` к :strong:`T3`, 
так как эти клиенты находятся в разных vlan. Здесь будет разобран :strong:`arp-запрос`.

.. code-block:: bash

    ping -c 1 192.168.20.1

В таблице маршрутизации нет отдельного маршрута для 20 подсети:

.. code-block:: bash

    t1 ~ ip route show
    default via 192.168.10.254 dev eth1
    192.168.10.0/24 dev eth1 proto kernel scope link src 192.168.10.1

Поэтому пакет будет отправлен через маршрут по умолчанию. Для этого клиент
отправит arp-запрос к ip ``192.168.10.254`` для получения его MAC.

:strong:`T1` знает MAC next-hop, поэтому дальше будет отправлен
:emphasis:`ICMP` пакет, а не :emphasis:`ARP`.
Пакет к :strong:`SW1` будет выглядеть следующим образом:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - 00:00:00:10:00:01"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.20.1"

На :strong:`SW1` этот пакет попадет через :emphasis:`eth2`,
где к нему будет добавлен vlan-тег:

.. mermaid ::

    packet-beta

    0-31: "802.1Q VLAN ID - 10"
    +16: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - 00:00:00:10:00:01"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.20.1"


Mac назначения это адрес SVI-интерфейса, поэтому пакет понимется для маршрутизации:

.. mermaid ::

    packet-beta

    0-15: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.20.1"

В таблице маршрутов 20 подсеть находится за SVI 20 vlan:

.. code-block:: bash

    sw1 ~ ip route show
    192.168.20.0/24 dev vlan20 proto kernel scope link src 192.168.20.254

Пакет будет отправлен в 20 vlan бриджа. Mac :emphasis:`T3` нет на бридже,
поэтому дальше будет отправлен broacast arp запрос. Который попадет на интерфейс vxlan0
и будет энкапсулирован.

Пакет будет выглядеть так:

.. mermaid ::

    packet-beta

    +16: "Source MAC - 00:00:00:20:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.20.254"
    +16: "Destination IP - 192.168.20.1"

В :strong:`frr` на

Этот пакет будет отправляться по всем RT-3 маршрутам
в этом vni. В underlay-сети он будет выглядеть так:

.. mermaid ::

    packet-beta

    0-15: "Underlay source MAC - 00:00:00:00:01:01"
    +16: "Underlay destination MAC - 00:00:00:00:01:02"
    +16: "Underlay source IP - 1.1.1.1"
    +16: "Underlay destination IP - 2.2.2.2"
    +16: "Source MAC - 00:00:00:20:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.20.254"
    +16: "Destination IP - 192.168.20.1"
    +32: "Vni - 120"

На :strong:`SW2` этот пакет попадет в vlan 20 бриджа
и отправится на :emphasis:`eth3`.

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:20:00:01"
    +16: "Destination MAC - ff:ff:ff:ff:ff:ff"
    +16: "Source IP - 192.168.20.254"
    +16: "Destination IP - 192.168.20.1"

:strong:`T3` получит обычный arp-запрос от интерфейса :emphasis:`vlan-10` SW1.
Клиент отправит ответ, который с помощью коммутации дойдет до SVI 20 vlan на SW1.

После прохождения этого пакета на свичах появится RT-2 запись с маком :emphasis:`T1`:

.. tabs::

   .. tab:: SW1

        .. code-block:: ini

            sw1# show bgp l2vpn evpn route type 2 
            BGP table version is 5, local router ID is 192.168.20.254
            Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
            Origin codes: i - IGP, e - EGP, ? - incomplete
            EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
            EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
            EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
            EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
            EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

            Network          Next Hop            Metric LocPrf Weight Path
                                Extended Community
            Route Distinguisher: 192.168.20.254:3
            *>  [2]:[0]:[48]:[00:00:00:01:00:01]
                                1.1.1.1                            32768 i
                                ET:8 RT:65000:110
            *>  [2]:[0]:[48]:[00:00:00:01:00:01]:[32]:[192.168.10.1]
                                1.1.1.1                            32768 i
                                ET:8 RT:65000:110

            Displayed 2 prefixes (2 paths) (of requested type)

   .. tab:: SW2

        .. code-block:: ini

            sw2# show bgp l2vpn evpn route type 2 
            BGP table version is 3, local router ID is 192.168.20.253
            Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
            Origin codes: i - IGP, e - EGP, ? - incomplete
            EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
            EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
            EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
            EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
            EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

            Network          Next Hop            Metric LocPrf Weight Path
                                Extended Community
            Route Distinguisher: 192.168.20.254:3
            *>i [2]:[0]:[48]:[00:00:00:01:00:01]
                                1.1.1.1                       100      0 i
                                RT:65000:110 ET:8
            *>i [2]:[0]:[48]:[00:00:00:01:00:01]:[32]:[192.168.10.1]
                                1.1.1.1                       100      0 i
                                RT:65000:110 ET:8

            Displayed 2 prefixes (2 paths) (of requested type)

Устройства изучили MAC T1 и его Ip.

RT-2 запись с одним MAC соответствует fdb-записи:

.. code-block:: bash

    sw2 ~ bridge fdb show
    00:00:00:01:00:01 dev vxlan0 dst 1.1.1.1 src_vni 110 self extern_learn

RT-2 запись MAC + Ip соответсвует arp-записи:

.. code-block:: bash

    sw2 ~ ip neigh show 
    192.168.10.1 dev vlan10 lladdr 00:00:00:01:00:01 extern_learn NOARP proto zebra

Прохождение unicast-трафика
***************************

Unicast трафик будет разобран на примере icmp-запроса из предыдущей главы.
Icmp-пакет в системе остался в таком виде:

.. mermaid ::

    packet-beta

    0-15: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.20.1"

После того, как SW1 получит arp ответ от T3, в arp таблице появится запись:

.. code-block:: bash

    sw1 ~ ip neigh show
    192.168.20.1 dev vlan20 lladdr 00:00:00:01:00:03 extern_learn NOARP proto zebra

Система отправит пакет на ip-адрес из arp-таблицы в vlan20.
В качестве MAC источника будет взять адрес svi.
В бридже будет такой пакет:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:01:00:03"
    +16: "Destination MAC - 00:00:00:20:00:01"
    +16: "Source IP - 192.168.20.1"
    +16: "Destination IP - 192.168.10.1"

Энкапсуляция и декапсуляция на другой стороне будет являться коммутацией.

Cимметричный irb
~~~~~~~~~~~~~~~~

Топология
"""""""""

.. uml::

    @startditaa
                       loopback0 1.1.1.1                   loopback0 2.2.2.2                   
                       SVI10 192.168.10.254                SVI20 192.168.20.254                 
                       00:00:00:10:00:01                   00:00:00:20:00:02                  
                           +-----+                             +-----+                         
                           |     |          VNI 11000          |     |                         
          ingress+---------+ SW1 +-----------------------------+ SW2 |----------+              
          pvid 10|     eth2|     |eth1                     eth1|     |eth2      |ingress       
                 |         +-----+10.0.0.0             10.0.0.1+-----+          |pvid 20       
                 |            00:00:00:00:01:01   00:00:00:00:01:02             |              
                 |                                                              |              
              +--+-+                                                          +-+--+           
              |    |                                                          |    |           
              | T1 |                                                          | T2 |           
              |    |                                                          |    |           
              +----+                                                          +----+           
     00:00:00:01:00:01                                                   00:00:00:01:00:02     
       192.168.10.1/24                                                  192.168.20.1/24        
    default gw 192.168.10.254                                         default gw 192.168.20.254
    @endditaa

Основное назначение симметричного irb в уменьшении количества vni на устройствах.
Так как пакеты между vtep будут ходить в одном служебном vni, нет необходимости
настраивать все vni на всех vtep.

Информация об RT-2 маршрутах передается между l2vni, т.е. fdb-записи
и arp-записи между разными vni не будут передаваться,
поэтому при симметричном irb используется l3vni, передающий только маршруты.

Настройка FRR
"""""""""""""

.. tabs::

   .. tab:: SW1

        .. code-block:: bash

            vrf vrf11000
             vni 11000
            exit-vrf
            !
            router bgp 65000
             neighbor 10.0.0.1 remote-as internal
             !
             address-family ipv4 unicast
              network 1.1.1.1/32
             exit-address-family
             !
             address-family l2vpn evpn
              neighbor 10.0.0.1 activate
              advertise-all-vni
              advertise-svi-ip
             exit-address-family
            exit
            !
            router bgp 65000 vrf vrf11000
             !
             address-family l2vpn evpn
              advertise ipv4 unicast
              advertise ipv6 unicast
             exit-address-family
            exit
            !
            end

   .. tab:: SW2

        .. code-block:: bash

            vrf vrf11000
             vni 11000
            exit-vrf
            !
            router bgp 65000
             neighbor 10.0.0.0 remote-as internal
             !
             address-family ipv4 unicast
              network 2.2.2.2/32
             exit-address-family
             !
             address-family l2vpn evpn
              neighbor 10.0.0.0 activate
              advertise-all-vni
              advertise-svi-ip
             exit-address-family
            exit
            !
            router bgp 65000 vrf vrf11000
             !
             address-family l2vpn evpn
              advertise ipv4 unicast
              advertise ipv6 unicast
             exit-address-family
            exit
            !
            end

:emphasis:`Bgp` используется как для :emphasis:`overlay-сети`, так и для :emphasis:`underlay-сети`.
Для упрощения настраивается :strong:`ibgp`, но разницы с :strong:`ebgp` не будет.

Оба устройства:

* Находятся в :emphasis:`AS 65000`
* Анонсируют свои :emphasis:`loopback-адреса` в :emphasis:`underlay-сети`
* Отсылают все свои :emphasis:`vni`
* Отсылают все свои :emphasis:`l3vni`
* Также отправляют маршруты внутри :emphasis:`vrf11000`

На этом настройка :strong:`frr` заканчивается. Для старой модели :emphasis:`traditional vxlan device`
конфигурация не отличается.

Настройка Linux
"""""""""""""""

.. tabs::

   .. tab:: SW1

        .. code-block:: bash

            # Loopback
            ip link add dev loopback0 type dummy
            ip addr add 1.1.1.1/32 dev loopback0
            ip link set loopback0 up

            # Underlay
            ip link set dev eth1 address 00:00:00:00:01:01
            ip address add 10.0.0.0/31 dev eth1

            # Bridge
            ip link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0
            ip link add vxlan0 type vxlan dstport 4789 local 1.1.1.1 nolearning external vnifilter
            ip link set vxlan0 master br0
            ip link set br0 up
            ip link set vxlan0 up
            bridge link set dev vxlan0 vlan_tunnel on

            # vrf for l3vni 11000
            ip link add vrf11000 type vrf table 11000
            ip link set vrf11000 up

            # l3vni 11000 - vlan 1100
            bridge vlan add dev br0 vid 1100 self
            bridge vlan add dev vxlan0 vid 1100
            bridge vni add dev vxlan0 vni 11000
            bridge vlan add dev vxlan0 vid 1100 tunnel_info id 11000
            ip link add vlan1100 link br0 type vlan id 1100
            ip link set vlan1100 master vrf11000
            ip link set dev vlan1100 address 00:00:11:00:00:01
            ip link set vlan1100 up

            # l2vni 110 - vlan 10
            bridge vlan add dev br0 vid 10 self
            bridge vlan add dev vxlan0 vid 10
            bridge vni add dev vxlan0 vni 110
            bridge vlan add dev vxlan0 vid 10 tunnel_info id 110
            ip link add vlan10 link br0 type vlan id 10
            ip link set vlan10 master vrf11000
            ip link set dev vlan10 address 00:00:00:10:00:01
            ip addr add 192.168.10.254/24 dev vlan10
            ip link set vlan10 up

            # Client link
            ip link set dev eth2 master br0
            bridge vlan add vid 10 dev eth2 pvid 10 egress untagged

   .. tab:: SW2

        .. code-block:: bash

            # Loopback
            ip link add dev loopback0 type dummy
            ip addr add 2.2.2.2/32 dev loopback0
            ip link set loopback0 up

            # Underlay
            ip link set dev eth1 address 00:00:00:00:01:02
            ip address add 10.0.0.1/31 dev eth1

            # Bridge
            ip link add br0 type bridge vlan_filtering 1 vlan_default_pvid 0
            ip link add vxlan0 type vxlan dstport 4789 local 2.2.2.2 nolearning external vnifilter
            ip link set vxlan0 master br0
            ip link set br0 up
            ip link set vxlan0 up
            bridge link set dev vxlan0 vlan_tunnel on

            # vrf for l3vni 11000
            ip link add vrf11000 type vrf table 11000
            ip link set vrf11000 up

            # l3vni 11000 - vlan 1100
            bridge vlan add dev br0 vid 1100 self
            bridge vlan add dev vxlan0 vid 1100
            bridge vni add dev vxlan0 vni 11000
            bridge vlan add dev vxlan0 vid 1100 tunnel_info id 11000
            ip link add vlan1100 link br0 type vlan id 1100
            ip link set vlan1100 master vrf11000
            ip link set dev vlan1100 address 00:00:11:00:00:02
            ip link set vlan1100 up

            # l2vni 120 - vlan 20
            bridge vlan add dev br0 vid 20 self
            bridge vlan add dev vxlan0 vid 20
            bridge vni add dev vxlan0 vni 120
            bridge vlan add dev vxlan0 vid 20 tunnel_info id 120
            ip link add vlan20 link br0 type vlan id 20
            ip link set vlan20 master vrf11000
            ip link set dev vlan20 address 00:00:00:20:00:01
            ip addr add 192.168.20.254/24 dev vlan20
            ip link set vlan20 up

            # Client link
            ip link set dev eth2 master br0
            bridge vlan add vid 20 dev eth2 pvid 20 egress untagged

   .. tab:: T1

        .. code-block:: bash

            ip link set dev eth1 address 00:00:00:01:00:01
            ip addr add 192.168.10.1/24 dev eth1

            ip route replace default via 192.168.10.254 dev eth1

   .. tab:: T2

        .. code-block:: bash

            ip link set dev eth1 address 00:00:00:01:00:02
            ip addr add 192.168.20.1/24 dev eth1

            ip route replace default via 192.168.20.254 dev eth1

:strong:`Loopback` интерфейс нужен для анонсирования :strong:`RT-3 маршрутов`.
Для распространения RT=3 маршрутов можно использовать и физический линк,
но в таком случае устройство сможет построить evpn-связность только на этом линке.
:strong:`Frr` анонсирует ip-адрес loopback-интерфейса в :emphasis:`underlay`,
а на других vtep этот адрес будет использоваться как next-hop для энкапсулированного пакета.

Для :strong:`underlay` интерфейсов используется :strong:`p2p` адресация, что позволяет
экономить адресное пространство.

:strong:`Bridge` должен быть сконфигурирован в режиме ``vlan_filtering 1``.
Это нужно, чтобы внутри бриджа пакеты учитывали vlan при коммутации и пакеты между
разными vni могли только маршрутизироваться.

При создании :strong:`Vxlan` интерфейса указывается ip-адрес, он будет использоваться
в качестве src-ip в :emphasis:`underlay` пакете.

:strong:`Svi` интерфейсы для каждого :emphasis:`vlan`, включая служебны,
добавляются в vrf.

Перед настройкой :strong:`vni-vlan mapping` нужно добавить vni и vlan на интерфейс.

Состояние стенда
""""""""""""""""

Vni:

.. tabs::

   .. tab:: SW1

        .. code-block:: ini

            sw1# show evpn vni 
            VNI        Type VxLAN IF              # MACs   # ARPs   # Remote VTEPs  Tenant VRF                           
            110        L2   vxlan0                1        1        0               vrf11000                             
            11000      L3   vxlan0                1        1        n/a             vrf11000

   .. tab:: SW2

        .. code-block:: ini

            sw2# show evpn vni 
            VNI        Type VxLAN IF              # MACs   # ARPs   # Remote VTEPs  Tenant VRF                           
            120        L2   vxlan0                1        1        0               vrf11000                             
            11000      L3   vxlan0                1        1        n/a             vrf11000

Evpn-маршруты:

.. tabs::

   .. tab:: SW1

        .. code-block:: ini

            sw1# show bgp l2vpn evpn 
            BGP table version is 3, local router ID is 172.20.20.3
            Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
            Origin codes: i - IGP, e - EGP, ? - incomplete
            EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
            EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
            EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
            EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
            EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

               Network          Next Hop            Metric LocPrf Weight Path
            Route Distinguisher: 172.20.20.3:2
             *>  [2]:[0]:[48]:[00:00:00:10:00:01]:[32]:[192.168.10.254]
                                1.1.1.1                            32768 i
                                ET:8 RT:65000:110 RT:65000:11000 Rmac:00:00:11:00:00:01
             *>  [3]:[0]:[32]:[1.1.1.1]
                                1.1.1.1                            32768 i
                                ET:8 RT:65000:110
            Route Distinguisher: 172.20.20.4:2
             *>i [2]:[0]:[48]:[00:00:00:20:00:01]:[32]:[192.168.20.254]
                                2.2.2.2                       100      0 i
                                RT:65000:120 RT:65000:11000 ET:8 Rmac:00:00:11:00:00:02
             *>i [3]:[0]:[32]:[2.2.2.2]
                                2.2.2.2                       100      0 i
                                RT:65000:120 ET:8

            Displayed 4 out of 4 total prefixes

   .. tab:: SW2

        .. code-block:: ini

            sw2# show bgp l2vpn evpn
            BGP table version is 2, local router ID is 172.20.20.4
            Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
            Origin codes: i - IGP, e - EGP, ? - incomplete
            EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
            EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
            EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
            EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
            EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

               Network          Next Hop            Metric LocPrf Weight Path
            Route Distinguisher: 172.20.20.3:2
             *>i [2]:[0]:[48]:[00:00:00:10:00:01]:[32]:[192.168.10.254]
                                1.1.1.1                       100      0 i
                                RT:65000:110 RT:65000:11000 ET:8 Rmac:00:00:11:00:00:01
             *>i [3]:[0]:[32]:[1.1.1.1]
                                1.1.1.1                       100      0 i
                                RT:65000:110 ET:8
            Route Distinguisher: 172.20.20.4:2
             *>  [2]:[0]:[48]:[00:00:00:20:00:01]:[32]:[192.168.20.254]
                                2.2.2.2                            32768 i
                                ET:8 RT:65000:120 RT:65000:11000 Rmac:00:00:11:00:00:02
             *>  [3]:[0]:[32]:[2.2.2.2]
                                2.2.2.2                            32768 i
                                ET:8 RT:65000:120

            Displayed 4 out of 4 total prefixes

Важным параметром является Rmac. Он используется для разграничения l3vni.
После того, как пакет пройдет vxlan-интерфейс и декапсулируется, он окажется
в бридже в служебном vlan, из которого он не сможет выйти на маршрутизацию.
Для того, чтобы пакет поднялся из vlan, в overlay-mac назначения должен быть
указан MAC адрес svi-интерфейса служебного vlan. Это позволит
пакету подняться из бриджа и попасть в нужный vrf.

Прохождение трафика
"""""""""""""""""""

Для передачи пакетов между разными vlan на клиентах указывается маршрут
по умолчанию через :emphasis:`svi-интерфейс` ближайшего свича.

Для демонстрации будет отправлен пакет от :strong:`T1` к :strong:`T2`, 
так как эти клиенты находятся в одном vlan. Здесь будет разобран :strong:`arp-запрос`.

.. code-block:: bash

    ping -c 1 192.168.20.1

В таблице маршрутизации нет отдельного маршрута для 20 подсети:

.. code-block:: bash

    t1 ~ ip route show
    default via 192.168.10.254 dev eth1
    192.168.10.0/24 dev eth1 proto kernel scope link src 192.168.10.1

Поэтому пакет будет отправлен через маршрут по умолчанию. Для этого клиент
отправит arp-запрос к ip ``192.168.10.254`` для получения его MAC.

:strong:`T1` знает MAC next-hop, поэтому дальше будет отправлен
:emphasis:`ICMP` пакет, а не :emphasis:`ARP`.
Пакет к :strong:`SW1` будет выглядеть следующим образом:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - 00:00:00:10:00:01"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.20.1"

На :strong:`SW1` этот пакет попадет через :emphasis:`eth2`,
где к нему будет добавлен vlan-тег:

.. mermaid ::

    packet-beta

    0-31: "802.1Q VLAN ID - 10"
    +16: "Source MAC - 00:00:00:01:00:01"
    +16: "Destination MAC - 00:00:00:10:00:01"
    +16: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.20.1"

Mac назначения это адрес SVI-интерфейса, поэтому пакет понимется для маршрутизации:

.. mermaid ::

    packet-beta

    0-15: "Source IP - 192.168.10.1"
    +16: "Destination IP - 192.168.20.1"

Т.к svi-интерфейс находится в vrf11000, пакет попадет в этот vrf.
В его таблице маршрутов нет маршрута для 20 подсети:

.. code-block:: bash

    sw1 ~ ip route show vrf vrf11000
    192.168.10.0/24 dev vlan10 proto kernel scope link src 192.168.10.254 
    192.168.20.254 nhid 12 via 2.2.2.2 dev vlan1100 proto bgp metric 20 onlink

Поэтому пакет будет терминирован. Но фабрика узнает о :strong:`T1`
и он станет доступным. После того, как :strong:`T2` отправит пакет,
фабрика узнает о нем и T1 сможет достучаться до T2.

Evpn-маршруты:

.. code-block:: ini

    sw2# show bgp l2vpn evpn route 
    BGP table version is 3, local router ID is 172.20.20.3
    Status codes: s suppressed, d damped, h history, * valid, > best, i - internal
    Origin codes: i - IGP, e - EGP, ? - incomplete
    EVPN type-1 prefix: [1]:[EthTag]:[ESI]:[IPlen]:[VTEP-IP]:[Frag-id]
    EVPN type-2 prefix: [2]:[EthTag]:[MAClen]:[MAC]:[IPlen]:[IP]
    EVPN type-3 prefix: [3]:[EthTag]:[IPlen]:[OrigIP]
    EVPN type-4 prefix: [4]:[ESI]:[IPlen]:[OrigIP]
    EVPN type-5 prefix: [5]:[EthTag]:[IPlen]:[IP]

    Network          Next Hop            Metric LocPrf Weight Path
                        Extended Community
    Route Distinguisher: 172.20.20.3:2
    *>  [2]:[0]:[48]:[00:00:00:20:00:01]:[32]:[192.168.20.254]
                        2.2.2.2                            32768 i
                        ET:8 RT:65000:120 RT:65000:11000 Rmac:00:00:11:00:00:02
    *>  [3]:[0]:[32]:[2.2.2.2]
                        2.2.2.2                            32768 i
                        ET:8 RT:65000:120
    Route Distinguisher: 172.20.20.4:2
    *>i [2]:[0]:[48]:[00:00:00:01:00:01]
                        1.1.1.1                       100      0 i
                        RT:65000:110 ET:8
    *>i [2]:[0]:[48]:[00:00:00:01:00:01]:[32]:[192.168.10.1]
                        1.1.1.1                       100      0 i
                        RT:65000:110 RT:65000:11000 ET:8 Rmac:00:00:11:00:00:01
    *>i [2]:[0]:[48]:[00:00:00:10:00:01]:[32]:[192.168.10.254]
                        1.1.1.1                       100      0 i
                        RT:65000:110 RT:65000:11000 ET:8 Rmac:00:00:11:00:00:01
    *>i [3]:[0]:[32]:[1.1.1.1]
                        1.1.1.1                       100      0 i
                        RT:65000:110 ET:8

    Displayed 6 prefixes (6 paths)

Теперь SW-2 сможет отправить пакет к T1.

Для демонстрации работы всей системы отправим пакет с :strong:`T2` к :strong:`T1`

.. code-block:: bash

    ping -c 1 192.168.10.1

В таблице маршрутизации нет отдельного маршрута для 10 подсети:

.. code-block:: bash

    t2 ~ ip route show
    default via 192.168.20.254 dev eth1
    192.168.20.0/24 dev eth1 proto kernel scope link src 192.168.20.1

Поэтому пакет будет отправлен через маршрут по умолчанию. Для этого клиент
отправит arp-запрос к ip ``192.168.20.254`` для получения его MAC.

:strong:`T2` знает MAC next-hop, поэтому дальше будет отправлен
:emphasis:`ICMP` пакет, а не :emphasis:`ARP`.
Пакет к :strong:`SW2` будет выглядеть следующим образом:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:01:00:02"
    +16: "Destination MAC - 00:00:00:20:00:01"
    +16: "Source IP - 192.168.20.1"
    +16: "Destination IP - 192.168.10.1"

На :strong:`SW2` этот пакет попадет через :emphasis:`eth2`,
где к нему будет добавлен vlan-тег:

.. mermaid ::

    packet-beta

    0-31: "802.1Q VLAN ID - 20"
    +16: "Source MAC - 00:00:00:01:00:02"
    +16: "Destination MAC - 00:00:00:20:00:01"
    +16: "Source IP - 192.168.20.1"
    +16: "Destination IP - 192.168.10.1"

Mac назначения это адрес SVI-интерфейса, поэтому пакет понимется для маршрутизации:

.. mermaid ::

    packet-beta

    0-15: "Source IP - 192.168.20.1"
    +16: "Destination IP - 192.168.10.1"

Т.к svi-интерфейс находится в vrf11000, пакет попадет в этот vrf.
В этом vrf есть маршрут к T1:

.. code-block:: bash

    sw2 ~ ip route show vrf vrf11000
    192.168.10.1 nhid 12 via 1.1.1.1 dev vlan1100 proto bgp metric 20 onlink 
    192.168.10.254 nhid 12 via 1.1.1.1 dev vlan1100 proto bgp metric 20 onlink 
    192.168.20.0/24 dev vlan20 proto kernel scope link src 192.168.20.254 

Систетма отправит пакет к T1 с next-hop :strong:`1.1.1.1`.
MAC назначения будет взят из arp-таблицы:

.. code-block:: bash

    sw2 ~ ip neigh show vrf vrf11000
    1.1.1.1 dev vlan1100 lladdr 00:00:11:00:00:01 extern_learn NOARP proto zebra 

Пакет будет отправлен на vlan1100 и будет выглядеть так:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:11:00:00:02"
    +16: "Destination MAC - 00:00:11:00:00:01"
    +16: "Source IP - 192.168.20.1"
    +16: "Destination IP - 192.168.10.1"

Этот пакет попадет на бридж, через который на vxlan-интерфейс, где будет энкапсулирован.
Работа underlay-сети была описана ранее.

На :strong:`SW1` после декапсуляции пакет окажется в бридже, в vlan 1100:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:11:00:00:02"
    +16: "Destination MAC - 00:00:11:00:00:01"
    +16: "Source IP - 192.168.20.1"
    +16: "Destination IP - 192.168.10.1"

Его MAC назначения совпадает с адресом svi-интерфейса, поэтому
пакет отправится на коммутацию в vrf11000.

В таблице маршрутизации для vrf есть 10 подсетка:

.. code-block:: bash

    sw1 ~ ip route show vrf vrf11000
    192.168.10.0/24 dev vlan10 proto kernel scope link src 192.168.10.254
    192.168.20.1 nhid 12 via 2.2.2.2 dev vlan1100 proto bgp metric 20 onlink
    192.168.20.254 nhid 12 via 2.2.2.2 dev vlan1100 proto bgp metric 20 onlink

Поэтому пакет будет отправлен в vlan 10 и MAC его svi-интерфейса
будет использован как MAC отправителя.

MAC адрес назначения будет взят из arp-таблицы:

.. code-block:: bash

    sw1 ~ ip neigh show vrf vrf11000
    2.2.2.2 dev vlan1100 lladdr 00:00:11:00:00:02 extern_learn NOARP proto zebra
    192.168.10.1 dev vlan10 lladdr 00:00:00:01:00:01 REACHABLE

:strong:`T1` получит обычный пакет:

.. mermaid ::

    packet-beta

    0-15: "Source MAC - 00:00:00:10:00:01"
    +16: "Destination MAC - 00:00:00:01:00:01"
    +16: "Source IP - 192.168.20.1"
    +16: "Destination IP - 192.168.10.1"

Ответ пойдет аналогичным образом.

.. toctree::
   :maxdepth: 2
   :caption: Contents:
