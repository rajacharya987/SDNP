<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        User::firstOrCreate(
            ['email' => 'admin@safelink.ai'],
            [
                'name' => 'SafeLink Admin',
                'password' => Hash::make('secret123'),
            ]
        );
    }
}
