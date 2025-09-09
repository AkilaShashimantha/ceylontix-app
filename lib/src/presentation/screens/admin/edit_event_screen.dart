import 'package:flutter/material.dart';
import '../../../data/repositories/firebase_event_repository.dart';
import '../../../domain/entities/event.dart';
import '../../../domain/entities/ticket_tier.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_textfield.dart';

class EditEventScreen extends StatefulWidget {
  final Event event;
  const EditEventScreen({Key? key, required this.event}) : super(key: key);

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _venueController;
  late TextEditingController _posterUrlController;

  DateTime? _selectedDate;
  late List<TicketTier> _ticketTiers;
  bool _isLoading = false;

  final FirebaseEventRepository _eventRepository = FirebaseEventRepository();

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with the existing event data
    _nameController = TextEditingController(text: widget.event.name);
    _descriptionController = TextEditingController(text: widget.event.description);
    _venueController = TextEditingController(text: widget.event.venue);
    _posterUrlController = TextEditingController(text: widget.event.posterUrl);
    _selectedDate = widget.event.date;
    // Create a mutable copy of the ticket tiers list
    _ticketTiers = List<TicketTier>.from(widget.event.ticketTiers);
  }

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

  void _addOrEditTicketTier({TicketTier? existingTier, int? index}) {
    final bool isEditing = existingTier != null;
    final tierNameController = TextEditingController(text: isEditing ? existingTier.name : '');
    final tierPriceController = TextEditingController(text: isEditing ? existingTier.price.toString() : '');
    final tierQuantityController = TextEditingController(text: isEditing ? existingTier.quantity.toString() : '');
    final tierFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Edit Ticket Tier' : 'Add Ticket Tier'),
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
                final newTier = TicketTier(
                  name: tierNameController.text,
                  price: double.parse(tierPriceController.text),
                  quantity: int.parse(tierQuantityController.text),
                );
                setState(() {
                  if (isEditing) {
                    _ticketTiers[index!] = newTier;
                  } else {
                    _ticketTiers.add(newTier);
                  }
                });
                Navigator.of(context).pop();
              }
            },
            child: Text(isEditing ? 'Save' : 'Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate() || _selectedDate == null || _ticketTiers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields, pick a date, and add at least one ticket tier.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final updatedEvent = Event(
        id: widget.event.id, // CRITICAL: Pass the ID for the update
        name: _nameController.text,
        description: _descriptionController.text,
        venue: _venueController.text,
        date: _selectedDate!,
        posterUrl: _posterUrlController.text,
        ticketTiers: _ticketTiers,
      );
      await _eventRepository.updateEvent(updatedEvent);
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event updated successfully!'), backgroundColor: Colors.green));
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
      appBar: AppBar(title: const Text('Edit Event')),
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
                  IconButton(icon: const Icon(Icons.add), onPressed: _addOrEditTicketTier, tooltip: 'Add Tier'),
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
                            onTap: () => _addOrEditTicketTier(existingTier: tier, index: index),
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
                onPressed: _updateEvent,
                text: 'Save Changes',
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}