<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ScanHistory extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'url',
        'domain',
        'verdict',
        'risk_score',
        'threat_details',
        'google_safe_browsing_status',
        'virustotal_status',
        'heuristics_status',
    ];

    protected $casts = [
        'threat_details' => 'array',
        'risk_score' => 'integer',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
