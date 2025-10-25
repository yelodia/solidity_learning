// test/utils/StorageHelper.js
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

class StorageHelper {
  constructor(storageLayoutPath, contractAddress, ethers) {
    const fullPath = path.resolve(storageLayoutPath);
    if (!fs.existsSync(fullPath)) {
      throw new Error(
        `Storage layout file not found: ${fullPath}\n` +
        `Please export storage layout first.`
      );
    }

    const layoutData = JSON.parse(fs.readFileSync(fullPath, 'utf8'));
    this.storage = layoutData.storage;
    this.types = layoutData.types;
    this.contractAddress = contractAddress;
    this.ethers = ethers; // ← Сохраняем переданный ethers

    if (!this.storage || !this.types) {
      throw new Error('Invalid storage layout format. Must contain "storage" and "types" fields.');
    }
  }

  async setVariable(variableName, value, key = null) {
    const variable = this._findVariable(variableName);
    const typeInfo = this.types[variable.type];
  
    if (typeInfo.encoding === 'mapping' && key === null) {
      throw new Error(
        `Variable "${variableName}" is a mapping. ` +
        `Use setVariable('${variableName}', value, key) with key parameter.`
      );
    }
  
    if (typeInfo.encoding === 'dynamic_array' && key === null) {
      throw new Error(
        `Variable "${variableName}" is a dynamic array. ` +
        `Use setArrayLength('${variableName}', length) and setArrayElement('${variableName}', index, value).`
      );
    }
  
    // Проверяем статический массив
    const isStaticArray = typeInfo.encoding === 'inplace' && typeInfo.label.includes('[');
    if (isStaticArray && key === null) {
      throw new Error(
        `Variable "${variableName}" is a static array. ` +
        `Use setArrayElement('${variableName}', index, value).`
      );
    }
  
    if (typeInfo.encoding === 'mapping') {
      await this._setMapping(variable, key, value);
    } else {
      await this._setSimpleVariable(variable, value);
    }
  }

  async setArrayLength(variableName, length) {
    const variable = this._findVariable(variableName);
    const typeInfo = this.types[variable.type];

    if (typeInfo.encoding !== 'dynamic_array') {
      throw new Error(`Variable "${variableName}" is not a dynamic array`);
    }

    await this._setStorageSlot(variable.slot, length);
  }

  async setArrayElement(variableName, index, value) {
    const variable = this._findVariable(variableName);
    const typeInfo = this.types[variable.type];
  
    // Определяем тип массива
    const isDynamicArray = typeInfo.encoding === 'dynamic_array';
    const isStaticArray = typeInfo.encoding === 'inplace' && typeInfo.label.includes('[');
  
    if (!isDynamicArray && !isStaticArray) {
      throw new Error(`Variable "${variableName}" is not an array`);
    }
  
    let baseSlot;
    let arrayLength;
  
    if (isDynamicArray) {
      // Для динамического массива данные начинаются с keccak256(slot)
      baseSlot = this.ethers.keccak256(
        this.ethers.AbiCoder.defaultAbiCoder().encode(['uint256'], [variable.slot])
      );
      // Длина хранится в самом слоте (можно прочитать, если нужна проверка)
      arrayLength = null; // не проверяем
    } else {
      // Для статического массива данные начинаются сразу с slot
      baseSlot = this.ethers.toBeHex(variable.slot);
      
      // Извлекаем длину из типа, например "uint24[7]" -> 7
      const match = typeInfo.label.match(/\[(\d+)\]/);
      if (match) {
        arrayLength = parseInt(match[1]);
        if (index >= arrayLength) {
          throw new Error(
            `Index ${index} out of bounds for array ${variableName}[${arrayLength}]`
          );
        }
      }
    }
  
    // Получаем тип элемента
    const elementTypeInfo = this.types[typeInfo.base];
    const elementBytes = parseInt(elementTypeInfo.numberOfBytes);
  
    if (elementBytes === 32) {
      // Элементы занимают полный слот (uint256, address, bytes32...)
      const elementSlot = BigInt(baseSlot) + BigInt(index);
      const formattedValue = this._formatValue(value, elementTypeInfo);
      await this._setStorageSlot(elementSlot, formattedValue);
    } else {
      // Элементы упакованы (uint8, uint24, uint32, uint16...)
      const elementsPerSlot = Math.floor(32 / elementBytes);
      
      // Вычисляем слот и offset
      const slotIndex = Math.floor(index / elementsPerSlot);
      const offsetInSlot = (index % elementsPerSlot) * elementBytes;
      
      const elementSlot = BigInt(baseSlot) + BigInt(slotIndex);
      
      // Читаем текущий слот
      const currentSlot = await this.ethers.provider.getStorage(
        this.contractAddress,
        elementSlot
      );
      
      // Используем логику packed storage
      const numberOfBits = elementBytes * 8;
      const offsetBits = offsetInSlot * 8;
      
      const mask = (1n << BigInt(numberOfBits)) - 1n;
      const currentSlotBN = BigInt(currentSlot);
      const clearedSlot = currentSlotBN & ~(mask << BigInt(offsetBits));
      
      const valueBN = this._valueToNumber(value, elementTypeInfo);
      const maskedValue = valueBN & mask;
      const shiftedValue = maskedValue << BigInt(offsetBits);
      const newSlot = clearedSlot | shiftedValue;
      
      await this._setStorageSlot(elementSlot, newSlot);
    }
  }

  async _setMapping(variable, key, value) {
    const typeInfo = this.types[variable.type];
    const keyType = this.types[typeInfo.key];
    const valueType = this.types[typeInfo.value];

    let encodedKey;
    const abiCoder = this.ethers.AbiCoder.defaultAbiCoder();
    
    if (keyType.label === 'address') {
      encodedKey = abiCoder.encode(['address', 'uint256'], [key, variable.slot]);
    } else if (keyType.label.startsWith('uint') || keyType.label.startsWith('int')) {
      encodedKey = abiCoder.encode(['uint256', 'uint256'], [key, variable.slot]);
    } else if (keyType.label === 'bytes32') {
      encodedKey = abiCoder.encode(['bytes32', 'uint256'], [key, variable.slot]);
    } else {
      throw new Error(`Unsupported mapping key type: ${keyType.label}`);
    }

    const slot = this.ethers.keccak256(encodedKey);
    const formattedValue = this._formatValue(value, valueType);

    await this._setStorageSlot(slot, formattedValue);
  }

  async _setSimpleVariable(variable, value) {
    const typeInfo = this.types[variable.type];

    if (variable.offset === 0 && typeInfo.numberOfBytes === '32') {
      const formattedValue = this._formatValue(value, typeInfo);
      await this._setStorageSlot(variable.slot, formattedValue);
    } else {
      await this._setPackedVariable(variable, value);
    }
  }

  async _setPackedVariable(variable, value) {
    const typeInfo = this.types[variable.type];
    
    const currentSlot = await this.ethers.provider.getStorage(
      this.contractAddress,
      variable.slot
    );

    const numberOfBytes = parseInt(typeInfo.numberOfBytes);
    const numberOfBits = numberOfBytes * 8;
    const offsetBits = variable.offset * 8;

    const mask = (1n << BigInt(numberOfBits)) - 1n;
    const currentSlotBN = BigInt(currentSlot);
    const clearedSlot = currentSlotBN & ~(mask << BigInt(offsetBits));

    const valueBN = this._valueToNumber(value, typeInfo);
    const maskedValue = valueBN & mask;
    const shiftedValue = maskedValue << BigInt(offsetBits);
    const newSlot = clearedSlot | shiftedValue;

    await this._setStorageSlot(variable.slot, newSlot);
  }

  _valueToNumber(value, typeInfo) {
    if (typeInfo.label === 'address') {
      return BigInt(value);
    } else if (typeInfo.label === 'bool') {
      return BigInt(value ? 1 : 0);
    } else if (typeInfo.label.startsWith('uint') || typeInfo.label.startsWith('int')) {
      return BigInt(value);
    } else {
      throw new Error(`Cannot convert ${typeInfo.label} to number for packed storage`);
    }
  }

  _formatValue(value, typeInfo) {
    const label = typeInfo.label;

    if (label.startsWith('uint') || label.startsWith('int')) {
      const bigIntValue = typeof value === 'bigint' ? value : BigInt(value);
      return this.ethers.toBeHex(bigIntValue, 32);
    }

    if (label === 'address') {
      return this.ethers.zeroPadValue(value, 32);
    }

    if (label === 'bool') {
      return this.ethers.toBeHex(value ? 1 : 0, 32);
    }

    if (label === 'bytes32') {
      return this.ethers.zeroPadValue(value, 32);
    }

    if (label === 'string') {
      return this._formatString(value);
    }

    throw new Error(`Unsupported type for formatting: ${label}`);
  }

  _formatString(value) {
    const encoded = this.ethers.toUtf8Bytes(value);
    
    if (encoded.length < 32) {
      // Для короткой строки: данные слева + нули + (длина*2) справа
      const lengthByte = encoded.length * 2;
      
      // Получаем hex строки
      const dataHex = this.ethers.hexlify(encoded); // например "0x416c696365"
      
      // Удаляем "0x" префикс
      const dataWithoutPrefix = dataHex.slice(2); // "416c696365"
      
      // Паддим нулями до 62 символов (31 байт) - оставляем место для длины
      const paddedData = dataWithoutPrefix.padEnd(62, '0'); // "416c696365000...000"
      
      // Добавляем длину как последние 2 hex символа (1 байт)
      const lengthHex = lengthByte.toString(16).padStart(2, '0'); // "0a"
      
      // Собираем: 0x + данные + паддинг + длина
      const result = '0x' + paddedData + lengthHex;
      
      return result;
    } else {
      throw new Error('Long strings (>=32 bytes) are not supported yet.');
    }
  }

  async _setStorageSlot(slot, value) {
    let formattedSlot;
    if (typeof slot === 'string' && slot.startsWith('0x')) {
      formattedSlot = slot;
    } else if (typeof slot === 'bigint') {
      formattedSlot = '0x' + slot.toString(16);
    } else {
      formattedSlot = this.ethers.toBeHex(slot);
    }
    
    // ВАЖНО: Hardhat требует удаления leading zeros из слота
    // Но нужно правильно обработать строку с 0x префиксом
    if (formattedSlot !== '0x0') {
      // Убираем 0x, удаляем leading zeros, возвращаем 0x
      const withoutPrefix = formattedSlot.slice(2); // убираем "0x"
      const withoutLeadingZeros = withoutPrefix.replace(/^0+/, ''); // убираем leading zeros
      
      if (withoutLeadingZeros === '') {
        formattedSlot = '0x0';
      } else {
        formattedSlot = '0x' + withoutLeadingZeros;
      }
    }
  
    let formattedValue;
    if (typeof value === 'string' && value.startsWith('0x')) {
      formattedValue = this.ethers.zeroPadValue(value, 32);
    } else if (typeof value === 'bigint') {
      formattedValue = this.ethers.toBeHex(value, 32);
    } else if (typeof value === 'number') {
      formattedValue = this.ethers.toBeHex(value, 32);
    } else {
      formattedValue = this.ethers.toBeHex(value, 32);
    }
  
    await this.ethers.provider.send("hardhat_setStorageAt", [
      this.contractAddress,
      formattedSlot,
      formattedValue
    ]);
    await this.ethers.provider.send("evm_mine", []);
  }

  _findVariable(variableName) {
    const variable = this.storage.find(v => v.label === variableName);
    if (!variable) {
      const availableVars = this.storage.map(v => v.label).join(', ');
      throw new Error(
        `Variable "${variableName}" not found in storage layout.\n` +
        `Available variables: ${availableVars}`
      );
    }
    return variable;
  }

  listVariables() {
    console.log('\n📋 Storage Layout Variables:');
    console.log('─'.repeat(80));
    this.storage.forEach(v => {
      const typeInfo = this.types[v.type];
      console.log(
        `${v.label.padEnd(20)} | slot: ${v.slot.toString().padStart(3)} | ` +
        `offset: ${v.offset.toString().padStart(2)} | type: ${typeInfo.label.padEnd(30)}`
      );
    });
    console.log('─'.repeat(80) + '\n');
  }
}

export default StorageHelper;