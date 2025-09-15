import 'package:flutter/material.dart';
import '../../../data/repositories/firebase_event_repository.dart';
import '../../../domain/entities/event.dart';
import '../../../domain/entities/ticket_tier.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({Key? key}) : super(key: key);

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _posterUrlController = TextEditingController();

  DateTime? _selectedDate;
  final List<TicketTier> _ticketTiers = [];
  bool _isLoading = false;

  final FirebaseEventRepository _eventRepository = FirebaseEventRepository();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _posterUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _addTicketTier() {
    final tierNameController = TextEditingController();
    final tierPriceController = TextEditingController();
    final tierQuantityController = TextEditingController();
    final tierFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Ticket Tier'),
        content: Form(
          key: tierFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: tierNameController, decoration: const InputDecoration(labelText: 'Tier Name (e.g., VIP)'), validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: tierPriceController, decoration: const InputDecoration(labelText: 'Price (LKR)'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
              TextFormField(controller: tierQuantityController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (tierFormKey.currentState!.validate()) {
                setState(() {
                  _ticketTiers.add(TicketTier(
                    name: tierNameController.text,
                    price: double.parse(tierPriceController.text),
                    quantity: int.parse(tierQuantityController.text),
                  ));
                });
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null || _ticketTiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields, pick a date, and add at least one ticket tier.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newEvent = Event(
        name: _nameController.text,
        description: _descriptionController.text,
        venue: _venueController.text,
        date: _selectedDate!,
        posterUrl: _posterUrlController.text,
        ticketTiers: _ticketTiers,
      );
      await _eventRepository.addEvent(newEvent);
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event added successfully!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }

    } catch (e) {
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create New Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Event Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              CustomTextField(controller: _nameController, hintText: 'Event Name', prefixIcon: Icons.event_outlined, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              CustomTextField(controller: _descriptionController, hintText: 'Description', prefixIcon: Icons.description_outlined, maxLines: 5, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              CustomTextField(controller: _venueController, hintText: 'Venue', prefixIcon: Icons.place_outlined, validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 16),
              CustomTextField(controller: _posterUrlController, hintText: 'Poster Image URL', prefixIcon: Icons.image_outlined, validator: (v) => v!.isEmpty ? 'Required' : null, keyboardType: TextInputType.url),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDate == null
                          ? 'No date chosen!'
                          : 'Date: ${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  TextButton(onPressed: _pickDate, child: const Text('Choose Date')),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ticket Tiers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add), onPressed: _addTicketTier, tooltip: 'Add Tier'),
                ],
              ),
              const SizedBox(height: 8),
              _ticketTiers.isEmpty
                  ? const Center(child: Text('Please add at least one ticket tier.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _ticketTiers.length,
                      itemBuilder: (context, index) {
                        final tier = _ticketTiers[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(tier.name),
                            subtitle: Text('LKR ${tier.price.toStringAsFixed(2)} - ${tier.quantity} tickets'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => setState(() => _ticketTiers.removeAt(index)),
                            ),
                          ),
                        );
                      },
                    ),
              const SizedBox(height: 32),
              CustomButton(
                onPressed: _saveEvent,
                text: 'Save Event',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}