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

Ассиметричный irb
~~~~~~~~~~~~~~~~~

Топология
"""""""""

.. uml::

    @startditaa
                loopback0 1.1.1.1                   loopback0 2.2.2.2
               SVI10 192.168.10.254                SVI20 192.168.10.253
               SVI20 192.168.20.254                SVI20 192.168.20.253
        ingress     +-----+                             +-----+     ingress
        pvid 10     |     |                             |     |     pvid 20
               +----+ SW1 +-----------------------------+ SW2 +----+
               |    |     |                             |     |    |
               |    +-----+10.0.0.0             10.0.0.1+-----+    |
               |       00:00:00:00:01:01   00:00:00:00:01:02       |
               |                                                   |
            +--+-+                                               +-+--+
            |    |                                               |    |
            | T1 |                                               | T2 |
            |    |                                               |    |
            +----+                                               +----+
   00:00:00:01:00:01                                        00:00:00:01:00:02
     192.168.10.1/24                                       192.168.20.1/24
  default gw 192.168.10.254                              default gw 192.168.20.253
    @endditaa


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
            ip link add dev dummy0 type dummy
            ip addr add 1.1.1.1/32 dev dummy0
            ip link set dummy0 up

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
            ip link add dev dummy0 type dummy
            ip addr add 2.2.2.2/32 dev dummy0
            ip link set dummy0 up

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

            # Client link
            ip link set dev eth2 master br0
            bridge vlan add vid 20 dev eth2 pvid 20 egress untagged

   .. tab:: T1

        .. code-block:: bash

            ip link set dev eth1 address 00:00:00:01:00:01
            ip addr add 192.168.10.1/24 dev eth1

            ip route add 192.168.20.0/24 via 192.168.10.254 dev eth1

   .. tab:: T2

        .. code-block:: bash

            ip link set dev eth1 address 00:00:00:01:00:02
            ip addr add 192.168.20.1/24 dev eth1

            ip route add 192.168.10.0/24 via 192.168.20.253 dev eth1





.. toctree::
   :maxdepth: 2
   :caption: Contents:

