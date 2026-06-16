.. Single vxlan device documentation master file, created by
   sphinx-quickstart on Mon Jun 15 18:11:05 2026.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Сравнение моделей vxlan устройств в ядре Linux
==============================================

Актуальный **frr** поддерживает обе модели, и ему не важно как будет настроено
**ядро**.

Traditional vxlan device
------------------------

Multiple bridge
~~~~~~~~~~~~~~~

**Frr** поддерживает мультбриджовую настройку.
При таком подходе бридж будет играть роль *SVI-интерфейса*.
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


Так как *vni-vlan* маппинг идет один к одному, а в такой схеме  
*vxlan* 


Single bridge
~~~~~~~~~~~~~

Другим вариантом является использование одного бриджа в режиме
``vlan_filter``. В этом режиме бридж будет использовать фильтрацию по *vlan*,
т.е. пакеты не будут пересылаться между разными *vlan* в рамках коммутации пакетов.
Это важно, чтобы пакеты между разными *vni* могли только маршрутизироваться


.. code-block:: bash

    # Bridge
    ip link add dev br0 type bridge
    ip link set dev br0 type bridge vlan_filter 1 vlan_default_pvid 0
    bridge vlan add dev br0 vid 10 self
    bridge vlan add dev br0 vid 20 self
    ip link set dev br0 up


.. toctree::
   :maxdepth: 2
   :caption: Contents:

