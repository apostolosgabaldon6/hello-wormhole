// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

/// @title HelloWormhole - Пример контракта для отправки и получения сообщений через Wormhole Relayer
/// @notice Этот контракт демонстрирует передачу строковых сообщений между цепочками
contract HelloWormhole is IWormholeReceiver {
    /// @notice Событие, которое эмитируется при получении приветствия
    /// @param greeting Текст приветствия
    /// @param senderChain ID цепочки, откуда пришло сообщение
    /// @param sender Адрес отправителя
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    /// @notice Ограничение по газу для выполнения сообщений на целевой цепочке
    uint256 public constant GAS_LIMIT = 50_000;

    /// @notice Интерфейс Wormhole Relayer для отправки сообщений
    IWormholeRelayer public immutable wormholeRelayer;

    /// @notice Последнее полученное приветствие
    string public latestGreeting;

    /// @param _wormholeRelayer Адрес контракта Wormhole Relayer
    constructor(address _wormholeRelayer) {
        require(_wormholeRelayer != address(0), "WormholeRelayer address cannot be zero");
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    /// @notice Рассчитывает стоимость отправки сообщения на целевую цепочку
    /// @param targetChain Целевая цепочка (chainId)
    /// @return cost Стоимость выполнения сообщения в wei
    function quoteCrossChainGreeting(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0, // Нулевая плата для получателя
            GAS_LIMIT
        );
    }

    /// @notice Отправляет сообщение (приветствие) на целевую цепочку
    /// @param targetChain ID целевой цепочки
    /// @param targetAddress Адрес контракта-получателя на целевой цепочке
    /// @param greeting Сообщение для отправки
    function sendCrossChainGreeting(
        uint16 targetChain,
        address targetAddress,
        string memory greeting
    ) public payable {
        require(targetAddress != address(0), "Target address cannot be zero");
        require(bytes(greeting).length > 0, "Greeting cannot be empty");

        uint256 cost = quoteCrossChainGreeting(targetChain);
        require(msg.value >= cost, "Insufficient funds for delivery");

        // Отправка сообщения через Wormhole Relayer
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(greeting, msg.sender), // Payload
            0, // Без оплаты получателю
            GAS_LIMIT
        );
    }

    /// @notice Обрабатывает входящие сообщения от Wormhole Relayer
    /// @param payload Данные сообщения (закодированные)
    /// @param additionalVaas Дополнительные VAA (не используются)
    /// @param sourceAddress Адрес контракта, отправившего сообщение
    /// @param sourceChain ID цепочки-отправителя
    /// @param deliveryHash Уникальный хеш доставки
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalVaas,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Unauthorized: Caller must be WormholeRelayer");

        // Декодирование полезной нагрузки
        (string memory greeting, address sender) = abi.decode(payload, (string, address));

        // Обновление последнего приветствия и эмиссия события
        latestGreeting = greeting;
        emit GreetingReceived(greeting, sourceChain, sender);
    }
}
