<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class BreachLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'identifier',
        'breach_count',
        'is_breached',
        'breach_details',
    ];

    protected $casts = [
        'breach_details' => 'array',
        'is_breached' => 'boolean',
        'breach_count' => 'integer',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
