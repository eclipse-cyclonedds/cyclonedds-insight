from PySide6.QtCore import QObject, Property, Slot, Signal, QVariant

class Address(QObject):
    def __init__(self, street="", city="", zip_code=""):
        super().__init__()
        self._street = street
        self._city = city
        self._zip_code = zip_code

    @Property(str)
    def street(self):
        return self._street

    @street.setter
    def street(self, value):
        self._street = value

    @Property(str)
    def city(self):
        return self._city

    @city.setter
    def city(self, value):
        self._city = value

    @Property(str)
    def zip_code(self):
        return self._zip_code

    @zip_code.setter
    def zip_code(self, value):
        self._zip_code = value

class Person(QObject):
    addressesChanged = Signal()

    def __init__(self, name="", age=0, addresses=None):
        super().__init__()
        self._name = name
        self._age = age
        self._addresses = addresses if addresses is not None else []

    @Property(str)
    def name(self):
        return self._name

    @name.setter
    def name(self, value):
        self._name = value

    @Property(int)
    def age(self):
        return self._age

    @age.setter
    def age(self, value):
        self._age = value

    @Property('QVariantList', notify=addressesChanged)
    def addresses(self):
        return self._addresses

    @Slot(str, str, str)
    def add_address(self, street="", city="", zip_code=""):
        address = Address(street, city, zip_code)
        self._addresses.append(address)
        self.addressesChanged.emit()

    @Slot(int)
    def remove_address(self, index):
        if 0 <= index < len(self._addresses):
            del self._addresses[index]
            self.addressesChanged.emit()
