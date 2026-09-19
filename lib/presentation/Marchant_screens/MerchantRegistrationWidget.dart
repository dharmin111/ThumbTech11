import 'package:flutter/material.dart';

class MerchantRegistrationWidget extends StatelessWidget {
  final bool isMerchantSelected; // ✅ true = merchant, false = customer
  final ValueChanged<bool> onToggle; // ✅ Callback with true/false

  const MerchantRegistrationWidget({
    super.key,
    required this.isMerchantSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    bool isMerchant = isMerchantSelected;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: GestureDetector(
        onTap: () {
          // ✅ Toggle: false → true, true → false
          onToggle(!isMerchant);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isMerchant ? const Color(0xFFE8FAF8) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF35B9B0),
              width: isMerchant ? 2 : 1,
            ),
            boxShadow: isMerchant
                ? [
              BoxShadow(
                color: const Color(0xFF00A99D).withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
                : null,
          ),
          child: Row(
            children: [
              // Store Icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isMerchant
                      ? const Color(0xFF00A99D)
                      : const Color(0xFFE8FAF8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isMerchant ? Icons.check : Icons.storefront_outlined,
                  color: isMerchant ? Colors.white : const Color(0xFF00A99D),
                  size: 24,
                ),
              ),

              const SizedBox(width: 10),

              // Middle Text
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Are you a Store / Parts Supplier?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Register your store and get more\n'
                          'customers (Technicians) near you.',
                      style: TextStyle(
                        fontSize: 9.5,
                        height: 1.25,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right Side
              if (isMerchant)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF00A99D),
                      size: 20,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Selected',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00A99D),
                      ),
                    ),
                  ],
                )
              else
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Register as',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00A99D),
                          ),
                        ),
                        Text(
                          'a Merchant',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00A99D),
                          ),
                        ),
                      ],
                    ),

                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}