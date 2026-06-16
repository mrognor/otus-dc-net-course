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


Так как *vni-vlan* маппинг идет один к одному, а в такой схеме на каждый *vlan*
создается бридж, то и для каждого маппинга нужен свой *vxlan-интерфейс*.


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


Так как бридж в такой схеме один, нужно создавать отдельные *SVI-интерфейсы*
для каждого *vlan*:


.. code-block:: bash

    # Svi 10
    ip link add link br0 dev vlan10 type vlan id 10
    ip address add 192.168.10.254/24 dev vlan10
    ip link set dev vlan10 up

    # Svi 20
    ip link add link br0 dev vlan20 type vlan id 20
    ip address add 192.168.20.254/24 dev vlan20
    ip link set dev vlan20 up


В традиционной модели *vxlan* каждый *vni-vlan* маппинг требует отдельного
*vxlan* интерфейса:


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


Такой интерфейс должен находиться в бридже в своем *vlan*. Он выполняет функцию
энкапсуляции пакетов. Например, *bum-трафик*, входящий в бридж, попадет на *vxlan-интерфейс*.
Там он обернется в обычный *ip-пакет* и будет отправлен на другие *vtep* с помощью *RT-3* маршрутов.


Single vxlan device
-------------------

Режим одного *vxlan-устройства* предполагает использование всего одного интерфейса.
Такая модель значительно ближе к вендорским прошивкам, и компактнее в плане настройки.

При создании *vxlan-интерфейса* нужно указать две дополнительные опции:
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


*Svi* все также нужен


.. code-block:: bash

    # Vlan 10
    ip link add vlan10 link br0 type vlan id 10
    ip addr add 192.168.10.254/24 dev vlan10
    ip link set vlan10 up

    # Vlan 20
    ip link add vlan20 link br0 type vlan id 20
    ip addr add 192.168.20.254/24 dev vlan20
    ip link set vlan20 up




Для установки маппинга между *vni* и *vlan* нужно:
1. Добавить бридж в *vlan*, чтобы пакеты могли выйти из него для маршрутизации
2. Добавить *vxlan-интерфейс* в *vlan*
3. Добавить *vxlan-интерфейс* в *vni*
4. Установить *vni-vlan* маппинг для *vxlan-интерфейса*

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



.. toctree::
   :maxdepth: 2
   :caption: Contents:

