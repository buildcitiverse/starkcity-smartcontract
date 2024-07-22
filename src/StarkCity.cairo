// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^0.14.0

#[starknet::contract]
mod StarkCity {
    use openzeppelin::access::ownable::OwnableComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::ERC721HooksEmptyImpl;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::interface::IUpgradeable;
    use starknet::ClassHash;
    use starknet::ContractAddress;
    use starknet::get_caller_address;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: OwnableComponent, storage: ownable, event: OwnableEvent);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);

    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721MixinImpl<ContractState>;
    #[abi(embed_v0)]
    impl OwnableMixinImpl = OwnableComponent::OwnableMixinImpl<ContractState>;

    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;
    impl OwnableInternalImpl = OwnableComponent::InternalImpl<ContractState>;
    impl UpgradeableInternalImpl = UpgradeableComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        ownable: OwnableComponent::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,

        base_data_uri: ByteArray,
        total_supply: u256,
        token_uri_mapping: LegacyMap<u256, u256>,
        init_minted: LegacyMap<ContractAddress, bool>,

        init_amount: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        OwnableEvent: OwnableComponent::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
    }

    #[constructor]
    fn constructor(ref self: ContractState, owner: ContractAddress) {
        self.erc721.initializer("StarkCity", "SKC", "");
        self.ownable.initializer(owner);
    }

    #[abi(embed_v0)]
    impl UpgradeableImpl of IUpgradeable<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            self.ownable.assert_only_owner();
            self.upgradeable.upgrade(new_class_hash);
        }
    }

    #[generate_trait]
    #[abi(per_item)]
    impl ExternalImpl of ExternalTrait {
        #[external(v0)]
        fn set_base_uri(ref self: ContractState, base_uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.erc721._set_base_uri(base_uri);
        }

        #[external(v0)]
        fn set_base_data_uri(ref self: ContractState, base_data_uri: ByteArray) {
            self.ownable.assert_only_owner();
            self.base_data_uri.write(base_data_uri);
        }

        #[external(v0)]
        fn set_init_amount(ref self: ContractState, init_amount: u256) {
            self.ownable.assert_only_owner();
            self.init_amount.write(init_amount);
        }

        #[external(v0)]
        fn safe_mint(
            ref self: ContractState,
            recipient: ContractAddress,
            token_id: u256,
            data: Span<felt252>,
        ) {
            self.erc721.safe_mint(recipient, token_id, data);
        }

        #[external(v0)]
        fn safeMint(
            ref self: ContractState,
            recipient: ContractAddress,
            tokenId: u256,
            data: Span<felt252>,
        ) {
            self.safe_mint(recipient, tokenId, data);
        }

        #[external(v0)]
        fn total_supply(ref self: ContractState) -> u256 {
            self.total_supply.read()
        }

        #[external(v0)]
        fn init_mint(ref self: ContractState) {
            let from = get_caller_address();
            assert(!self.init_minted.read(from), 'already minted');
            self.init_minted.write(from, true);
            
            let max_amount = self.init_amount.read();
            let mut count = 0;
            loop {
                let token_id = self.total_supply.read() + count;
                self.erc721.safe_mint(from, token_id, array![].span());
                self.token_uri_mapping.write(token_id, count);
                count += 1;
                if (count >= max_amount) {
                    break;
                }
            };

            self.total_supply.write(self.total_supply.read() + count);
        }

        #[external(v0)]
        fn token_data_uri(ref self: ContractState, token_id: u256) -> ByteArray {
            self.erc721._require_owned(token_id);
            let base_uri = self.base_data_uri.read();
            if base_uri.len() == 0 {
                return "";
            } else {
                return format!("{}{}", base_uri, self.token_uri_mapping.read(token_id));
            }
        }
    }
}