import 'package:flutter/material.dart';

class ProductSelectionScreen extends StatefulWidget {
  const ProductSelectionScreen({super.key});

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  String? selectedProduct;

  final List<String> products = [
    'Hovězí steak (61°C)',
    'Kuřecí prsa (74°C)',
    'Klobásky (71°C)',
    'Jehněčí maso (70°C)',
    'Vepřové maso (61°C)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vyberte produkt'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          ...products.map((product) {
            return RadioListTile<String>(
              title: Text(product),
              value: product,
              groupValue: selectedProduct,
              onChanged: (value) {
                setState(() {
                  selectedProduct = value;
                });
              },
            );
          }).toList(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                if (selectedProduct != null) {
                  Navigator.pop(context, selectedProduct);
                }
              },
              child: const Text('Potvrdit'),
            ),
          ),
        ],
      ),
    );
  }
}
